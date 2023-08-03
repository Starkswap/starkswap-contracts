#[starknet::contract]
mod StarkswapV1Pair {
    use starkswap_contracts::structs::observation::Observation;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1Curve;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1CurveDispatcherTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1CurveLibraryDispatcher;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1Factory;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1FactoryDispatcherTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1FactoryDispatcher;
    use starkswap_contracts::interfaces::IStarkswapV1Callee::IStarkswapV1Callee;
    use starkswap_contracts::interfaces::IStarkswapV1Callee::IStarkswapV1CalleeDispatcherTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Callee::IStarkswapV1CalleeDispatcher;
    use starkswap_contracts::utils::decimals::make_18_dec;
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use openzeppelin::token::erc20::erc20::ERC20;
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use starknet::contract_address_const;
    use zeroable::Zeroable;
    use integer::u256_from_felt252;
    use integer::u64_from_felt252;
    use integer::u256_sqrt;
    use array::ArrayTrait;
    use traits::Into;

    //const LOCKING_ADDRESS: ContractAddress = 42; // ERC20 mint does not allow `0`, so we use `42` instead
    const PERIOD_SIZE: felt252 = 1800; // Capture oracle reading every 30 minutes

    #[storage]
    struct Storage {
        sv_base_token_address: ContractAddress,
        sv_quote_token_address: ContractAddress,
        sv_curve: ClassHash,
        sv_base_token_reserve: u256,
        sv_quote_token_reserve: u256,
        sv_base_token_reserve_cumulative_last: u256,
        sv_quote_token_reserve_cumulative_last: u256,
        sv_observations: LegacyMap::<usize, Observation>,
        sv_observations_len: usize,
        sv_k_last: u256,
        sv_factory_address: ContractAddress,
        sv_block_timestamp_last: u64,
        sv_reentrancy_lock: bool,
    }

    #[event]
    fn ev_mint(sender: ContractAddress, base_amount: u256, quote_amount: u256) {}

    #[event]
    fn ev_burn(
        sender: ContractAddress, base_amount: u256, quote_amount: u256, to: ContractAddress
    ) {}

    #[event]
    fn ev_swap(
        sender: ContractAddress,
        base_token_amount_in: u256,
        quote_token_amount_in: u256,
        base_token_amount_out: u256,
        quote_token_amount_out: u256,
        to: ContractAddress,
    ) {}

    #[event]
    fn ev_sync(base_token_reserve: u256, quote_token_reserve: u256) {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        base_token_address: ContractAddress,
        quote_token_address: ContractAddress,
        curve_class_hash: ClassHash
    ) {
        let sender: ContractAddress = get_caller_address();
        self.sv_factory_address.write(sender);

        self.sv_base_token_address.write(base_token_address);
        self.sv_quote_token_address.write(quote_token_address);
        self.sv_curve.write(curve_class_hash);

        let block_timestamp = get_block_timestamp();
        self.sv_observations.write(
            0,
            Observation {
                block_timestamp: block_timestamp, cumulative_base_reserve: u256 {
                    low: 0, high: 0
                    }, cumulative_quote_reserve: u256 {
                    low: 0, high: 0
                }
            }
        );
        self.sv_observations_len.write(1);
        // TODO: name should be "StarkSwap V1 <Curve>" and Symbol should be "<base>/<quote>"
        ERC20::constructor(ref self, 'StarkswapV1', 'StarkswapV1', 0, contract_address_const::<0>());
    }

    #[external(v0)]
    impl StarkSwapV1PairERC20Impl of openzeppelin::token::erc20::interface::IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            return ERC20::name();
        }

        fn symbol(self: @ContractState) -> felt252 {
            return ERC20::symbol();
        }

        fn decimals(self: @ContractState) -> u8 {
            return ERC20::decimals();
        }

        fn total_supply(self: @ContractState) -> u256 {
            return ERC20::total_supply();
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            return ERC20::balance_of(account);
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            return ERC20::allowance(owner, spender);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            return ERC20::approve(spender, amount);
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            return ERC20::transfer(recipient, amount);
        }

        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            return ERC20::transfer_from(sender, recipient, amount);
        }
    }

    #[external(v0)]
    impl StarkSwapV1PairImpl of starkswap_contracts::interfaces::IStarkswapV1Pair::IStarkswapV1Pair<ContractState> {

        fn factory(self: @ContractState) -> ContractAddress {
            return self.sv_factory_address.read();
        }

        fn base_token(self: @ContractState) -> ContractAddress {
            return self.sv_base_token_address.read();
        }

        fn quote_token(self: @ContractState) -> ContractAddress {
            return self.sv_quote_token_address.read();
        }

        fn curve(self: @ContractState) -> (ClassHash, felt252) {
            let class_hash = self.sv_curve.read();
            let name = IStarkswapV1CurveLibraryDispatcher { class_hash: class_hash }.name();
            return (class_hash, name);
        }

        fn get_reserves(self: @ContractState) -> (u256, u256, u64) {
            let base_token_reserve = self.sv_base_token_reserve.read();
            let quote_token_reserve = self.sv_quote_token_reserve.read();
            let timestamp = self.sv_block_timestamp_last.read();

            return (base_token_reserve, quote_token_reserve, timestamp);
        }


        fn get_observations(self: @ContractState, num_observations: felt252) -> Array<Observation> {
            let mut amounts: Array<Observation> = ArrayTrait::new();
            let count = self.sv_observations_len.read();
            let mut i: usize = 0;

            loop {
                if i >= count {
                    break ();
                }
                let o: Observation = self.sv_observations.read(i);
                amounts.append(self.sv_observations.read(i));
                i = i + 1;
            };

            return amounts;
        }

        fn last_observation(self: @ContractState) -> Observation {
            return self._last_observation();
        }

        fn k_last(self: @ContractState) -> u256 {
            return self.sv_k_last.read();
        }


        fn mint(ref self: ContractState, to: ContractAddress) -> u256 {
            self._lock();
            let contract_address = get_contract_address();

            let base_token_address = self.sv_base_token_address.read();
            let base_token_reserve = self.sv_base_token_reserve.read();
            let quote_token_address = self.sv_quote_token_address.read();
            let quote_token_reserve = self.sv_quote_token_reserve.read();

            let base_token_balance = IERC20Dispatcher {
                contract_address: base_token_address
            }.balance_of(contract_address);
            let quote_token_balance = IERC20Dispatcher {
                contract_address: quote_token_address
            }.balance_of(contract_address);

            let base_token_amount = base_token_balance - base_token_reserve;
            let quote_token_amount = quote_token_balance - quote_token_reserve;

            let fee_on = self._mint_fee(base_token_reserve, quote_token_reserve);
            let total_supply = self.total_supply();

            let liquidity = self._calculate_liquidity(
                total_supply,
                base_token_amount,
                quote_token_amount,
                base_token_reserve,
                quote_token_reserve
            );

            //assert(liquidity > u256{ low: 0_u128, high: 0_u128 }, 'StarkswapV1: INSUFFICIENT_LIQUIDITY_MINTED');
            assert(liquidity > u256 { low: 0_u128, high: 0_u128 }, 'StarkswapV1: MINTED < MIN');
            ERC20::_mint(to, liquidity);

            self._update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

            if (fee_on == true) {
                self._update_k_last(base_token_balance, quote_token_balance);
                self._unlock();
                return liquidity;
            }

            let sender = get_caller_address();
            ev_mint(sender, base_token_amount, quote_token_amount);

            self._unlock();
            return liquidity;
        }

        fn burn(ref self: ContractState, to: ContractAddress) -> (u256, u256) {
            self._lock();
            let this_pair_address = get_contract_address();

            let base_token_address = self.sv_base_token_address.read();
            let base_token_reserve = self.sv_base_token_reserve.read();
            let quote_token_address = self.sv_quote_token_address.read();
            let quote_token_reserve = self.sv_quote_token_reserve.read();

            let base_token_balance = IERC20Dispatcher {
                contract_address: base_token_address
            }.balance_of(this_pair_address);
            let quote_token_balance = IERC20Dispatcher {
                contract_address: quote_token_address
            }.balance_of(this_pair_address);
            let liquidity = self.balance_of(this_pair_address);

            let fee_on = self._mint_fee(base_token_reserve, quote_token_reserve);
            let total_supply = self.total_supply();

            let base_token_amount = (liquidity * base_token_balance) / total_supply;

            let quote_token_amount = (liquidity * quote_token_balance) / total_supply;

            assert(base_token_amount > u256 { low: 0_u128, high: 0_u128 }, 'StarkswapV1: BURNED < MIN');
            assert(
                quote_token_amount > u256 { low: 0_u128, high: 0_u128 }, 'StarkswapV1: BURNED < MIN'
            );

            ERC20::_burn(this_pair_address, liquidity);
            IERC20Dispatcher { contract_address: base_token_address }.transfer(to, base_token_amount);
            IERC20Dispatcher { contract_address: quote_token_address }.transfer(to, quote_token_amount);

            let base_token_balance = IERC20Dispatcher {
                contract_address: base_token_address
            }.balance_of(this_pair_address);
            let quote_token_balance = IERC20Dispatcher {
                contract_address: quote_token_address
            }.balance_of(this_pair_address);

            self._update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

            let sender = get_caller_address();
            ev_burn(sender, base_token_amount, quote_token_amount, to);

            if (fee_on == true) {
                self._update_k_last(base_token_balance, quote_token_balance);
                self._unlock();
                return (base_token_amount, quote_token_amount);
            } else {
                self._unlock();
                return (base_token_amount, quote_token_amount);
            }
        }




        fn swap(
            ref self: ContractState,
            base_amount_out: u256,
            quote_amount_out: u256,
            to: ContractAddress,
            calldata: Array<felt252>,
        ) {
            self._lock();
            let contract_address = get_contract_address();

            // require(base_amount_out > 0 || quote_amount_out > 0)
            assert(
                base_amount_out + quote_amount_out > u256_from_felt252(0),
                'StarkswapV1: OUTPUT_AMOUNT<MIN'
            ); //StarkswapV1: INSUFFICIENT_OUTPUT_AMOUNT

            let base_token_address = self.sv_base_token_address.read();
            let base_token_reserve = self.sv_base_token_reserve.read();

            let quote_token_address = self.sv_quote_token_address.read();
            let quote_token_reserve = self.sv_quote_token_reserve.read();

            // require(baseAmout < baseReserve && quoteAmount < quoteReserve)
            assert(
                base_amount_out < base_token_reserve, 'StarkswapV1: LIQUIDITY < MIN'
            ); //StarkswapV1: INSUFFICIENT_LIQUIDITY
            assert(
                quote_amount_out < quote_token_reserve, 'StarkswapV1: LIQUIDITY < MIN'
            ); //StarkswapV1: INSUFFICIENT_LIQUIDITY
            assert(to != base_token_address, 'StarkswapV1: INVALID_TO');
            assert(to != quote_token_address, 'StarkswapV1: INVALID_TO');

            self._transfer_out(
                base_token_address, quote_token_address, base_amount_out, quote_amount_out, to
            );
            self._invoke_callee(base_amount_out, quote_amount_out, to, calldata);

            let base_token_decimals = IERC20Dispatcher {
                contract_address: base_token_address
            }.decimals();
            let quote_token_decimals = IERC20Dispatcher {
                contract_address: quote_token_address
            }.decimals();

            let base_token_balance = IERC20Dispatcher {
                contract_address: base_token_address
            }.balance_of(contract_address);
            let quote_token_balance = IERC20Dispatcher {
                contract_address: quote_token_address
            }.balance_of(contract_address);

            let base_amount_in = _calc_input_amount(
                base_token_reserve, base_token_balance, base_amount_out
            );
            let quote_amount_in = _calc_input_amount(
                quote_token_reserve, quote_token_balance, quote_amount_out
            );

            // require(base_amount_in > 0 || quote_amount_in > 0)
            assert(
                base_amount_in + quote_amount_in > u256_from_felt252(0),
                'StarkswapV1: INPUT_AMOUNT < MIN'
            ); //StarkswapV1: INSUFFICIENT_INPUT_AMOUNT

            let base_token_balance_adjusted = _calc_balance_adjusted(
                base_token_balance, base_amount_in
            );
            let quote_token_balance_adjusted = _calc_balance_adjusted(
                quote_token_balance, quote_amount_in
            );

            //with_attr error_message("StarkswapV1: K") {
            let base_reserve_adjusted = base_token_reserve * u256 { low: 1000, high: 0 };
            let quote_reserve_adjusted = quote_token_reserve * u256 { low: 1000, high: 0 };

            let class_hash = self.sv_curve.read();
            let (a0, b0) = _normalise_decimals(
                base_token_balance_adjusted,
                quote_token_balance_adjusted,
                base_token_decimals,
                quote_token_decimals,
            );
            let (a1, b1) = _normalise_decimals(
                base_reserve_adjusted, quote_reserve_adjusted, base_token_decimals, quote_token_decimals
            );
            let new_k = IStarkswapV1CurveLibraryDispatcher { class_hash: class_hash }.get_k(a0, b0);
            let old_k = IStarkswapV1CurveLibraryDispatcher { class_hash: class_hash }.get_k(a1, b1);

            assert(new_k >= old_k, 'StarkswapV1: K');
            //}

            self._update(base_token_balance, quote_token_balance, base_amount_out, quote_amount_out);
            let sender = get_caller_address();
            ev_swap(sender, base_amount_in, quote_amount_in, base_amount_out, quote_amount_out, to);

            self._unlock();
        }


        fn skim(ref self: ContractState, to: ContractAddress) {
            self._lock();
            let base_token_address = self.sv_base_token_address.read();
            let quote_token_address = self.sv_quote_token_address.read();
            let base_token_reserve = self.sv_base_token_reserve.read();
            let quote_token_reserve = self.sv_quote_token_reserve.read();

            let contract_address = get_contract_address();

            let base_token_balance = IERC20Dispatcher {
                contract_address: base_token_address
            }.balance_of(contract_address);
            let quote_token_balance = IERC20Dispatcher {
                contract_address: quote_token_address
            }.balance_of(contract_address);

            let base_token_amount = base_token_balance - base_token_reserve;
            let quote_token_amount = quote_token_balance - quote_token_reserve;

            IERC20Dispatcher { contract_address: base_token_address }.transfer(to, base_token_amount);
            IERC20Dispatcher { contract_address: quote_token_address }.transfer(to, quote_token_amount);

            self._unlock();
        }

        fn sync(ref self: ContractState) {
            self._lock();
            let base_token_address = self.sv_base_token_address.read();
            let quote_token_address = self.sv_quote_token_address.read();
            let base_token_reserve = self.sv_base_token_reserve.read();
            let quote_token_reserve = self.sv_quote_token_reserve.read();

            let contract_address = get_contract_address();

            let base_token_balance = IERC20Dispatcher {
                contract_address: base_token_address
            }.balance_of(contract_address);
            let quote_token_balance = IERC20Dispatcher {
                contract_address: quote_token_address
            }.balance_of(contract_address);

            self._update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

            self._unlock();
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {


        fn MINIMUM_LIQUIDITY(self: @ContractState) -> u256 {
            return u256_from_felt252(1000);
        }

        fn _last_observation(self: @ContractState) -> Observation {
            let count = self.sv_observations_len.read();
            let observation = self.sv_observations.read(count - 1);

            return observation;
        }

        fn _mint_fee(ref self: ContractState, base_token_reserve: u256, quote_token_reserve: u256) -> bool {
            let factory_address = self.sv_factory_address.read();
            let fee_to: ContractAddress = IStarkswapV1FactoryDispatcher {
                contract_address: factory_address
            }.fee_to_address();

            if (fee_to != Zeroable::zero()) {
                // # Fee is on

                let k_last: u256 = self.sv_k_last.read();
                if (k_last != u256_from_felt252(0)) {
                    //TODO: replace with curve get_k?
                    let k = base_token_reserve * quote_token_reserve;

                    let root_k = u256 { low: u256_sqrt(k), high: 0_u128 };
                    let root_k_last = u256 { low: u256_sqrt(k_last), high: 0_u128 };

                    if (root_k_last < root_k) {
                        let total_supply = self.total_supply();

                        let r0 = root_k - root_k_last;
                        let numerator = total_supply * r0;

                        let r1 = root_k * u256_from_felt252(5);
                        let denominator = r1 + root_k_last;

                        let liquidity = numerator / denominator;

                        if (liquidity > u256_from_felt252(0)) {
                            ERC20::_mint(fee_to, liquidity);
                        }
                    }
                }
                return true;
            } else {
                // # Fee is off
                self.sv_k_last.write(u256_from_felt252(0));
                return false;
            }
        }



        fn _update_cumulative_last_reserves(
            ref self: ContractState,
            time_elapsed: u64,
            base_token_reserve: u256,
            quote_token_reserve: u256,
            base_reserve_cumulative_last: u256,
            quote_reserve_cumulative_last: u256
        ) {
            // if (time_elapsed > 0 && base_reserve != 0 && quote_reserve != 0)
            if (time_elapsed > 0_u64) {
                if (base_token_reserve != u256_from_felt252(0)) {
                    if (quote_token_reserve != u256_from_felt252(0)) {
                        self.sv_base_token_reserve_cumulative_last.write(base_reserve_cumulative_last);
                        self.sv_quote_token_reserve_cumulative_last.write(quote_reserve_cumulative_last);
                    }
                }
            }
        }


        fn _update(
            ref self: ContractState,
            base_token_balance: u256,
            quote_token_balance: u256,
            base_token_reserve: u256,
            quote_token_reserve: u256
        ) -> () {
            let block_timestamp = get_block_timestamp();
            let block_timestamp_last = self.sv_block_timestamp_last.read();
            let time_elapsed = block_timestamp - block_timestamp_last;

            let base_reserve_cumulative_last_old = self.sv_base_token_reserve_cumulative_last.read();
            let quote_reserve_cumulative_last_old = self.sv_quote_token_reserve_cumulative_last.read();

            let base_reserve_cumulative_last = base_token_reserve * u256 {
                low: time_elapsed.into(), high: 0
            };
            let quote_reserve_cumulative_last = quote_token_reserve * u256 {
                low: time_elapsed.into(), high: 0
            };

            let base_reserve_cumulative_last = base_reserve_cumulative_last
                + base_reserve_cumulative_last_old;
            let quote_reserve_cumulative_last = quote_reserve_cumulative_last
                + quote_reserve_cumulative_last_old;

            self._update_cumulative_last_reserves(
                time_elapsed,
                base_token_reserve,
                quote_token_reserve,
                base_reserve_cumulative_last,
                quote_reserve_cumulative_last,
            );

            let last_observation = self._last_observation();
            let time_elapsed = block_timestamp - last_observation.block_timestamp;

            // if (timeElapsed > periodSize)
            // !(timeElapsed <= periodSize)
            if (time_elapsed > u64_from_felt252(PERIOD_SIZE)) {
                let observations_len = self.sv_observations_len.read();
                self.sv_observations.write(
                    observations_len,
                    Observation {
                        block_timestamp: block_timestamp,
                        cumulative_base_reserve: base_reserve_cumulative_last,
                        cumulative_quote_reserve: quote_reserve_cumulative_last
                    }
                );
                self.sv_observations_len.write(observations_len + 1);

                self.sv_base_token_reserve.write(base_token_balance);
                self.sv_quote_token_reserve.write(quote_token_balance);
                self.sv_block_timestamp_last.write(block_timestamp);
            } else {
                self.sv_base_token_reserve.write(base_token_balance);
                self.sv_quote_token_reserve.write(quote_token_balance);
                self.sv_block_timestamp_last.write(block_timestamp);
            }

            ev_sync(base_token_balance, quote_token_balance);
        }

        fn _calculate_liquidity(
            ref self: ContractState,
            total_supply: u256,
            base_token_amount: u256,
            quote_token_amount: u256,
            base_token_reserve: u256,
            quote_token_reserve: u256,
        ) -> u256 {
            let min_liquidity = self.MINIMUM_LIQUIDITY();

            if (total_supply == u256_from_felt252(0)) {
                let liquidity: u256 = u256 {
                    low: u256_sqrt(base_token_amount * quote_token_amount), high: 0
                } - min_liquidity;

                ERC20::_mint(contract_address_const::<42>(), min_liquidity);
                return liquidity;
            } else {
                let r1 = (base_token_amount * total_supply) / base_token_reserve;
                let r2 = (quote_token_amount * total_supply) / quote_token_reserve;

                if (r1 < r2) {
                    return r1;
                } else {
                    return r2;
                }
            }
        }

        fn _update_k_last(ref self: ContractState, base_token_reserve: u256, quote_token_reserve: u256) {
            let k_last = base_token_reserve * quote_token_reserve;
            self.sv_k_last.write(k_last);
        }

        fn _lock(ref self: ContractState) {
            let is_locked = self.sv_reentrancy_lock.read();
            assert(!is_locked, 'StarkswapV1: LOCKED');
            self.sv_reentrancy_lock.write(true);
        }

        fn _unlock(ref self: ContractState) {
            let is_locked = self.sv_reentrancy_lock.read();
            assert(is_locked, 'StarkswapV1: UNLOCKED');
            self.sv_reentrancy_lock.write(false);
        }

        fn _invoke_callee(
            self: @ContractState,
            base_amount_out: u256,
            quote_amount_out: u256,
            to: ContractAddress,
            calldata: Array<felt252>,
        ) {
            if (calldata.len() > 0) {
                let caller_address = get_caller_address();
                IStarkswapV1CalleeDispatcher {
                    contract_address: to
                }.starkswapV1Call(caller_address, base_amount_out, quote_amount_out, calldata);
            }
        }

        fn _transfer_out(
            ref self: ContractState,
            base_token_address: ContractAddress,
            quote_token_address: ContractAddress,
            base_amount_out: u256,
            quote_amount_out: u256,
            to: ContractAddress,
        ) {
            if (base_amount_out > u256_from_felt252(0)) {
                IERC20Dispatcher { contract_address: base_token_address }.transfer(to, base_amount_out);
            }
            if (quote_amount_out > u256_from_felt252(0)) {
                IERC20Dispatcher {
                    contract_address: quote_token_address
                }.transfer(to, quote_amount_out);
            }
        }
    }

    fn _normalise_decimals(
        reserve_a: u256, reserve_b: u256, decimals_a: u8, decimals_b: u8
    ) -> (u256, u256) {
        let reserve_a_normalised = make_18_dec(reserve_a, decimals_a);
        let reserve_b_normalised = make_18_dec(reserve_b, decimals_b);

        return (reserve_a_normalised, reserve_b_normalised);
    }

    fn _calc_balance_adjusted(balance: u256, amount_in: u256) -> u256 {
        let r0 = balance * u256 { low: 1000, high: 0 };
        let r1 = amount_in * u256 { low: 3, high: 0 };

        return r0 - r1;
    }

    fn _calc_input_amount(reserve: u256, balance: u256, amount_out: u256) -> u256 {
        let r0 = reserve - amount_out;

        if (balance > (reserve - amount_out)) {
            return balance - r0;
        } else {
            return u256_from_felt252(0);
        }
    }

}
