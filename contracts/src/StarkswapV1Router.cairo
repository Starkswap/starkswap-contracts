#[starknet::contract]
mod StarkswapV1Router {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use starknet::library_call_syscall;
    use starknet::contract_address_try_from_felt252;
    use starknet::contract_address_to_felt252;
    use starknet::class_hash_to_felt252;
    use starknet::class_hash_try_from_felt252;
    use starknet::call_contract_syscall;
    use starknet::get_block_timestamp;
    use zeroable::Zeroable;
    use integer::BoundedInt;
    use integer::u256_from_felt252;
    use integer::u128_to_felt252;
    use integer::u64_from_felt252;
    use array::ArrayTrait;
    use array::SpanTrait;
    use array::OptionTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1Curve;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1CurveDispatcherTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1CurveLibraryDispatcher;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1Factory;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1FactoryDispatcherTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1FactoryDispatcher;
    use starkswap_contracts::interfaces::IStarkswapV1Pair::IStarkswapV1Pair;
    use starkswap_contracts::interfaces::IStarkswapV1Pair::IStarkswapV1PairDispatcherTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Pair::IStarkswapV1PairDispatcher;
    use starkswap_contracts::utils::decimals::make_18_dec;
    use starkswap_contracts::utils::decimals::unmake_18_dec;
    use starkswap_contracts::structs::route::Route;
    use starkswap_contracts::structs::observation::Observation;
    use starkswap_contracts::utils::sort::_sort_tokens;
    use starkswap_contracts::utils::sort::_sort_amounts;
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;

    #[storage]
    struct Storage {
        sv_factory_address: ContractAddress,
        sv_pair_class_hash: ClassHash,
    }

    #[constructor]
    fn constructor(ref self: ContractState, factory_address: ContractAddress, pair_class_hash: ClassHash, ) {
        self.sv_factory_address.write(factory_address);
        self.sv_pair_class_hash.write(pair_class_hash);
    }

    #[external(v0)]
    impl StarkswapV1Router of starkswap_contracts::interfaces::IStarkswapV1Router::IStarkswapV1Router<ContractState> {
        fn factory(self: @ContractState) -> ContractAddress {
            return self.sv_factory_address.read();
        }

        fn pair_class_hash(self: @ContractState) -> ClassHash {
            return self.sv_pair_class_hash.read();
        }

        fn quote(self: @ContractState, amount_a: u256, reserve_a: u256, reserve_b: u256, ) -> u256 {
            return _quote(amount_a, reserve_a, reserve_b);
        }

        fn oracle_quote(
            self: @ContractState,
            pair_address: ContractAddress,
            token_in: ContractAddress,
            amount_in: u256,
            sample_count: felt252
        ) -> u256 {
            // TODO: surely there is a better way to do this assert than casting to u256...
            assert(u256_from_felt252(sample_count) > u256_from_felt252(0), 'SAMPLE_COUNT');

            let (input_token_address, output_token_address, is_input_base) = _in_out_token(
                pair_address, token_in
            );
            let observations = IStarkswapV1PairDispatcher {
                contract_address: pair_address
            }.get_observations(sample_count);
            let (curve, curve_name) = IStarkswapV1PairDispatcher {
                contract_address: pair_address
            }.curve();
            let decimals_in = IERC20Dispatcher { contract_address: input_token_address }.decimals();
            let decimals_out = IERC20Dispatcher { contract_address: output_token_address }.decimals();
            let price_average_cumulative = self._sample_cumulative_price(
                observations.len(),
                observations.span(),
                is_input_base,
                amount_in,
                decimals_in,
                decimals_out,
                curve
            );
            return price_average_cumulative / u256_from_felt252(sample_count);
        }

        fn get_amount_out(
            self: @ContractState,
            amount_in: u256,
            reserve_in: u256,
            reserve_out: u256,
            decimals_in: u8,
            decimals_out: u8,
            curve: ClassHash
        ) -> u256 {
            return self._get_amount_out(amount_in, reserve_in, reserve_out, decimals_in, decimals_out, curve);
        }

        fn get_amount_in(
            self: @ContractState,
            amount_out: u256,
            reserve_in: u256,
            reserve_out: u256,
            decimals_in: u8,
            decimals_out: u8,
            curve: ClassHash
        ) -> u256 {
           return self._get_amount_in(amount_out, reserve_in, reserve_out, decimals_in, decimals_out, curve);
        }

        fn get_amounts_out(self: @ContractState, amount_in: u256, routes: Array<Route>) -> Array<u256> {
            return self._get_amounts_out(amount_in, routes.span());
        }

        fn get_amounts_in(self: @ContractState, amount_out: u256, routes: Array<Route>) -> Array<u256> {
            return self._get_amounts_in(amount_out, routes.span());
        }

        fn add_liquidity(
            self: @ContractState,
            token_a_address: ContractAddress,
            token_b_address: ContractAddress,
            curve: ClassHash,
            amount_a_desired: u256,
            amount_b_desired: u256,
            amount_a_min: u256,
            amount_b_min: u256,
            to: ContractAddress,
            deadline: u64,
        ) -> (u256, u256, u256) {
            _assert_valid_deadline(deadline);

            let (amount_a, amount_b, pair_address) = self._add_liquidity(
                token_a_address,
                token_b_address,
                curve,
                amount_a_desired,
                amount_b_desired,
                amount_a_min,
                amount_b_min,
            );
            let caller_address = get_caller_address();
            IERC20Dispatcher {
                contract_address: token_a_address
            }.transfer_from(caller_address, pair_address, amount_a);
            IERC20Dispatcher {
                contract_address: token_b_address
            }.transfer_from(caller_address, pair_address, amount_b);
            let liquidity = IStarkswapV1PairDispatcher { contract_address: pair_address }.mint(to);
            return (amount_a, amount_b, liquidity);
        }

        fn remove_liquidity(
            self: @ContractState,
            token_a_address: ContractAddress,
            token_b_address: ContractAddress,
            curve: ClassHash,
            liquidity: u256,
            amount_a_min: u256,
            amount_b_min: u256,
            to: ContractAddress,
            deadline: u64,
        ) -> (u256, u256) {
            _assert_valid_deadline(deadline);

            let pair_address = _pair_for(self, token_a_address, token_b_address, curve);
            assert(!pair_address.is_zero(), 'NONEXISTENT_PAIR');

            let caller_address = get_caller_address();
            IERC20Dispatcher {
                contract_address: pair_address
            }.transfer_from(caller_address, pair_address, liquidity);
            let (amount_0, amount_1) = IStarkswapV1PairDispatcher {
                contract_address: pair_address
            }.burn(to);
            let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
            let (amount_a, amount_b) = _sort_amounts(token_a_address, base_address, amount_0, amount_1);

            assert(amount_a_min <= amount_a, 'INSUFFICIENT_A_AMOUNT');
            assert(amount_b_min <= amount_b, 'INSUFFICIENT_B_AMOUNT');

            return (amount_a, amount_b);
        }

        fn swap_exact_tokens_for_tokens(
            self: @ContractState,
            amount_in: u256,
            amount_out_min: u256,
            routes: Array<Route>,
            to: ContractAddress,
            deadline: u64,
        ) -> Array<u256> {
            _assert_valid_deadline(deadline);

            let amounts = self._get_amounts_out(amount_in, routes.span());
            assert(amount_out_min <= *amounts[amounts.len() - 1], 'INSUFFICIENT_OUTPUT_AMOUNT');

            self._swap(amounts.span(), routes.span(), to);

            return amounts;
        }

        fn swap_tokens_for_exact_tokens(
            self: @ContractState,
            amount_out: u256,
            amount_in_max: u256,
            routes: Array<Route>,
            to: ContractAddress,
            deadline: u64,
        ) -> Array<u256> {
            _assert_valid_deadline(deadline);

            let amounts = self._get_amounts_in(amount_out, routes.span());
            assert(*amounts[0] <= amount_in_max, 'INSUFFICIENT_INPUT_AMOUNT');

            self._swap(amounts.span(), routes.span(), to);

            return amounts;
        }
    }




    #[generate_trait]
    impl InternalImpl of InternalTrait {

        fn _get_amount_in(
            self: @ContractState,
            amount_out: u256,
            reserve_in: u256,
            reserve_out: u256,
            decimals_in: u8,
            decimals_out: u8,
            curve: ClassHash
        ) -> u256 {
            assert(amount_out > u256_from_felt252(0), 'INSUFFICIENT_OUTPUT_AMOUNT');
            assert(reserve_in > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
            assert(reserve_out > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');

            let ao = make_18_dec(amount_out, decimals_out);
            let ri = make_18_dec(reserve_in, decimals_in);
            let ro = make_18_dec(reserve_out, decimals_out);
            let amount_in = IStarkswapV1CurveLibraryDispatcher {
                class_hash: curve
            }.get_amount_in(ao, ri, ro, 0); //TODO: pass fees?
            return amount_in;
        }

        fn _get_amount_out(
            self: @ContractState,
            amount_in: u256,
            reserve_in: u256,
            reserve_out: u256,
            decimals_in: u8,
            decimals_out: u8,
            curve: ClassHash
        ) -> u256 {
            assert(amount_in > u256_from_felt252(0), 'INSUFFICIENT_INPUT_AMOUNT');
            assert(reserve_in > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
            assert(reserve_out > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');

            let ai = make_18_dec(amount_in, decimals_in);
            let ri = make_18_dec(reserve_in, decimals_in);
            let ro = make_18_dec(reserve_out, decimals_out);
            let amount_out = IStarkswapV1CurveLibraryDispatcher {
                class_hash: curve
            }.get_amount_out(ai, ri, ro);
            return unmake_18_dec(amount_out, decimals_out);
        }

        fn _get_reserves(
            self: @ContractState, token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
        ) -> (u256, u256) {
            let pair_address = IStarkswapV1FactoryDispatcher {
                contract_address: self.sv_factory_address.read()
            }.get_pair(token_a_address, token_b_address, curve);
            assert(!pair_address.is_zero(), 'INVALID_PATH');

            let (reserve_0, reserve_1, timestamp) = IStarkswapV1PairDispatcher {
                contract_address: pair_address
            }.get_reserves();
            let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
            if base_address == token_a_address {
                return (reserve_0, reserve_1);
            }
            return (reserve_1, reserve_0);
        }


        fn _get_or_create_pair(
            self: @ContractState, token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
        ) -> ContractAddress {
            let pair_address = IStarkswapV1FactoryDispatcher {
                contract_address: self.sv_factory_address.read()
            }.get_pair(token_a_address, token_b_address, curve);
            if !pair_address.is_zero() {
                return pair_address;
            }
            return IStarkswapV1FactoryDispatcher {
                contract_address: self.sv_factory_address.read()
            }.create_pair(token_a_address, token_b_address, curve);
        }

        fn _get_amounts_out(self: @ContractState, amount_in: u256, routes: Span<Route>) -> Array<u256> {
            assert(routes.len() >= 1, 'INVALID_PATH');
            let mut amounts = ArrayTrait::new();
            amounts.append(amount_in);
            let mut index = 0;
            loop {
                if index == routes.len() {
                    break;
                }
                let route: Route = *routes[index];
                let (reserve_in, reserve_out) = self._get_reserves(route.input, route.output, route.curve);
                let decimals_in = IERC20Dispatcher { contract_address: route.input }.decimals();
                let decimals_out = IERC20Dispatcher { contract_address: route.output }.decimals();
                let amount_out = self._get_amount_out(
                    *amounts[index], reserve_in, reserve_out, decimals_in, decimals_out, route.curve
                );
                amounts.append(amount_out);
                index = index + 1;
            };
            return amounts;
        }

        fn _get_amounts_in(self: @ContractState, amount_out: u256, routes: Span<Route>) -> Array<u256> {
            assert(routes.len() >= 1, 'INVALID_PATH');

            let mut amounts = ArrayTrait::new();
            amounts.append(amount_out);
            let mut index = 0;
            loop {
                if index == routes.len() {
                    break;
                }
                let route: Route = *routes[index];
                let (reserve_in, reserve_out) = self._get_reserves(route.input, route.output, route.curve);
                let decimals_in = IERC20Dispatcher { contract_address: route.input }.decimals();
                let decimals_out = IERC20Dispatcher { contract_address: route.output }.decimals();
                let amount_in = self._get_amount_in(
                    *amounts[index], reserve_in, reserve_out, decimals_in, decimals_out, route.curve
                );
                amounts.append(amount_in);
                index = index + 1;
            };
            // TODO: more efficient way to do this than reverse array? revert to recursion?
            let mut rev_amounts = ArrayTrait::new();
            index = amounts.len() - 1;
            loop {
                if index >= 0 {
                    rev_amounts.append(*amounts[index]);
                }
                if index <= 0 {
                    break;
                }
                index = index - 1;
            };
            return rev_amounts;
        }



        fn _add_liquidity(
            self: @ContractState,
            token_a_address: ContractAddress,
            token_b_address: ContractAddress,
            curve: ClassHash,
            amount_a_desired: u256,
            amount_b_desired: u256,
            amount_a_min: u256,
            amount_b_min: u256,
        ) -> (u256, u256, ContractAddress) {
            let pair_address = self._get_or_create_pair(token_a_address, token_b_address, curve);


            let (reserve_a, reserve_b) = self._get_reserves(token_a_address, token_b_address, curve);
            if reserve_a + reserve_b == u256_from_felt252(0) {
                return (amount_a_desired, amount_b_desired, pair_address);
            }

            let amount_b_optimal = _quote(amount_a_desired, reserve_a, reserve_b);
            if amount_b_optimal < amount_b_desired {
                assert(amount_b_min <= amount_b_optimal, 'INSUFFICIENT_B_AMOUNT');
                return (amount_a_desired, amount_b_optimal, pair_address);
            }

            let amount_a_optimal = _quote(amount_b_desired, reserve_b, reserve_a);
            assert(amount_a_optimal <= amount_a_desired, 'INSUFFICIENT_A_AMOUNT');
            assert(amount_a_min <= amount_a_optimal, 'INSUFFICIENT_A_AMOUNT');

            return (amount_a_optimal, amount_b_desired, pair_address);
        }

        fn _swap(self: @ContractState, amounts: Span<u256>, routes: Span<Route>, to: ContractAddress) {
            let route: Route = *routes[0];
            let pair_address = _pair_for(self, route.input, route.output, route.curve);
            let caller_address = get_caller_address();

            IERC20Dispatcher {
                contract_address: route.input
            }.transfer_from(caller_address, pair_address, *amounts[0]);

            let mut index = 0;
            loop {
                if index == routes.len() {
                    // TODO is this the correct break return val?
                    break;
                }

                let route: Route = *routes[index];
                let (base_token, _) = _sort_tokens(route.input, route.output);
                let (base_out, quote_out) = _sort_amounts(
                    route.input, base_token, u256_from_felt252(0), *amounts[index]
                );

                let mut to_address = to;
                if index < routes.len() - 1 {
                    let r: Route = *routes[index+1];
                    to_address = _pair_for(self, r.input, r.output, r.curve);
                }
                let pair_address = _pair_for(self, route.input, route.output, route.curve);

                IStarkswapV1PairDispatcher {
                    contract_address: pair_address
                }.swap(base_out, quote_out, to_address, ArrayTrait::<felt252>::new());

                index = index + 1;
            };
        }

        fn _sample_cumulative_price(
            self: @ContractState,
            observations_len: u32,
            observations: Span<Observation>,
            is_input_base: bool,
            amount_in: u256,
            decimals_in: u8,
            decimals_out: u8,
            curve: ClassHash,
        ) -> u256 {
            if observations_len < 2 {
                return u256_from_felt252(0);
            }

            let current_observation = *observations.at(observations.len() - observations_len);
            let next_observation = *observations.at(observations.len() - observations_len + 1);
            let (reserve_in, reserve_out) = _in_out_reserves(
                next_observation, current_observation, is_input_base
            );

            let amount_out = self._get_amount_out(
                amount_in, reserve_in, reserve_out, decimals_in, decimals_out, curve
            );
            let accumulator = self._sample_cumulative_price(
                observations_len - 1,
                observations,
                is_input_base,
                amount_in,
                decimals_in,
                decimals_out,
                curve,
            );

            return amount_out + accumulator;
        }

    }

    fn _in_out_token(
        pair_address: ContractAddress, token_in: ContractAddress
    ) -> (ContractAddress, ContractAddress, bool) {
        let base_token_address = IStarkswapV1PairDispatcher {
            contract_address: pair_address
        }.base_token();
        let quote_token_address = IStarkswapV1PairDispatcher {
            contract_address: pair_address
        }.quote_token();

        if token_in == base_token_address {
            return (base_token_address, quote_token_address, true);
        }

        if token_in == quote_token_address {
            return (quote_token_address, base_token_address, false);
        }

        return (
            contract_address_try_from_felt252(0).unwrap(),
            contract_address_try_from_felt252(0).unwrap(),
            false
        );
    }

    fn _in_out_reserves(
        next_observation: Observation, current_observation: Observation, is_input_base: bool
    ) -> (u256, u256) {
        let base_reserve = next_observation.cumulative_base_reserve
            - current_observation.cumulative_base_reserve;
        let quote_reserve = next_observation.cumulative_quote_reserve
            - current_observation.cumulative_quote_reserve;

        if is_input_base == true {
            return (base_reserve, quote_reserve);
        }
        return (quote_reserve, base_reserve);
    }



    fn _quote(amount_a: u256, reserve_a: u256, reserve_b: u256, ) -> u256 {
        assert(amount_a > u256_from_felt252(0), 'INSUFFICIENT_AMOUNT');
        assert(reserve_a > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        assert(reserve_b > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        return (amount_a * reserve_b) / reserve_a;
    }

    fn _pair_for(
        self: @ContractState, token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
    ) -> ContractAddress {
        //TODO: Can this be replicated in cairo 1 or do we need to simply make a factory call?
        // let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
        // return calculate_contract_address(
        //     salt=0,
        //     class_hash=sv_pair_class_hash.read(),
        //     constructor_calldata_size=3,
        //     constructor_calldata=(base_address, quote_address, curve),
        //     deployer_address=sv_factory.read(),
        // );

        let factory_address: ContractAddress = self.sv_factory_address.read();
        return IStarkswapV1FactoryDispatcher {
            contract_address: factory_address
        }.get_pair(token_a_address, token_b_address, curve);
    }

    fn _assert_valid_deadline(deadline: u64) {
        let block_timestamp= get_block_timestamp();
        assert(block_timestamp <= deadline, 'EXPIRED');
    }

    //#[event]
    //#[derive(Drop, starknet::Event)]
    //enum Event {
        //Upgraded: Upgraded
    //}

    //#[derive(Drop, starknet::Event)]
    //struct Upgraded {
        //implementation: ClassHash
    //}

    //#[generate_trait]
    //#[external(v0)]
    //impl UpgradeableContract of IUpgradeableContract {
        //fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            //assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
            //starknet::replace_class_syscall(impl_hash).unwrap();
            //self.emit(Event::Upgraded(Upgraded { implementation: impl_hash }))
        //}

        //fn version(self: @ContractState) -> u8 {
            //0
        //}
    //}

}
