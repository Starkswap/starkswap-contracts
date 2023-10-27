#[starknet::contract]
mod StarkswapV1Factory {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use starknet::contract_address_to_felt252;
    use starknet::class_hash_to_felt252;
    use starknet::deploy_syscall;
    use zeroable::Zeroable;
    use integer::BoundedInt;
    use array::ArrayTrait;
    use array::SpanTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Pair::IStarkswapV1Pair;
    use starkswap_contracts::interfaces::IStarkswapV1Pair::IStarkswapV1PairDispatcherTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Pair::IStarkswapV1PairDispatcher;
    use starkswap_contracts::structs::route::Route;
    use starkswap_contracts::structs::pair::Pair;
    use starkswap_contracts::structs::token::Token;
    use starkswap_contracts::structs::balance::Balance;
    use starkswap_contracts::utils::sort::_sort_tokens;
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use traits::Into;

    #[storage]
    struct Storage {
        sv_factory_address: ContractAddress,
        sv_pair_class_hash: ClassHash,
        sv_curve_class_hash: LegacyMap::<ClassHash, bool>,
        sv_fee_to_setter_address: ContractAddress,
        sv_fee_to_address: ContractAddress,
        sv_all_pairs_length: u64,
        sv_pairs: LegacyMap::<(ContractAddress, ContractAddress, ClassHash), ContractAddress>,
        sv_pair_by_index: LegacyMap::<u64, ContractAddress>
    }

    #[constructor]
    fn constructor(ref self: ContractState, fee_to_setter_address: ContractAddress, pair_class_hash: ClassHash) {
        assert(!fee_to_setter_address.is_zero(), 'ZERO_FEE_TO_SETTER_ADDRESS');
        assert(!pair_class_hash.is_zero(), 'ZERO_PAIR_CLASS_HASH');
        self.sv_fee_to_setter_address.write(fee_to_setter_address);
        self.sv_pair_class_hash.write(pair_class_hash);
    }

    #[external(v0)]
    impl StarkswapV1Factory of starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1Factory<ContractState> {
        fn fee_to_address(self: @ContractState) -> ContractAddress {
            return self.sv_fee_to_address.read();
        }

        fn pair_class_hash(self: @ContractState) -> ClassHash {
            return self.sv_pair_class_hash.read();
        }

        fn fee_to_setter_address(self: @ContractState) -> ContractAddress {
            return self.sv_fee_to_setter_address.read();
        }

        fn curve_class_hash(self: @ContractState, curve_class_hash: ClassHash) -> bool {
            return self.sv_curve_class_hash.read(curve_class_hash);
        }

        fn get_pair(
            self: @ContractState, token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
        ) -> ContractAddress {
            let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
            return self.sv_pairs.read((base_address, quote_address, curve));
        }

        fn all_pairs(self: @ContractState, index: u64) -> ContractAddress {
            assert(index < self.sv_all_pairs_length.read(), 'INVALID_INDEX');
            return self.sv_pair_by_index.read(index);
        }

        fn all_pairs_length(self: @ContractState) -> u64 {
            return self.sv_all_pairs_length.read();
        }

        fn get_all_pairs(self: @ContractState) -> Array<Pair> {
            let mut pairs = ArrayTrait::new();
            let all_pairs_length = self.sv_all_pairs_length.read();
            let mut index = 0;
            loop {
                if index == all_pairs_length {
                    // TODO is this the correct break return val?
                    break 0;
                }

                let pair_address = self.sv_pair_by_index.read(index);
                let base_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.base_token();
                let quote_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.quote_token();
                let (curve, _) = IStarkswapV1PairDispatcher { contract_address: pair_address }.curve();

                let pair_name = IERC20Dispatcher { contract_address: pair_address }.name();
                let pair_symbol = IERC20Dispatcher { contract_address: pair_address }.symbol();
                let pair_decimals = IERC20Dispatcher { contract_address: pair_address }.decimals();
                let pair_token: Token = Token {
                    address: pair_address,
                    name: pair_name,
                    symbol: pair_symbol,
                    decimals: pair_decimals
                };

                let base_name = IERC20Dispatcher{ contract_address: base_address }.name();
                let base_symbol = IERC20Dispatcher{ contract_address: base_address }.symbol();
                let base_decimals = IERC20Dispatcher{ contract_address: base_address }.decimals();
                let base_token: Token = Token{
                    address: base_address,
                    name: base_name,
                    symbol: base_symbol,
                    decimals: base_decimals
                };

                let quote_name = IERC20Dispatcher{ contract_address: quote_address }.name();
                let quote_symbol = IERC20Dispatcher{ contract_address: quote_address }.symbol();
                let quote_decimals = IERC20Dispatcher{ contract_address: quote_address }.decimals();
                let quote_token: Token = Token{
                    address: quote_address,
                    name: quote_name,
                    symbol: quote_symbol,
                    decimals: quote_decimals
                };

                pairs.append(Pair {
                    pair: pair_token,
                    base: base_token,
                    quote: quote_token,
                    curve
                });

                index = index + 1;
            };
            return pairs;
        }

        fn create_pair(
            ref self: ContractState, token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
        ) -> ContractAddress {

            assert(self.sv_curve_class_hash.read(curve) == true, 'INVALID_CURVE');
            assert(token_a_address != token_b_address, 'INVALID_ADDRESSES');

            let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);

            assert(!base_address.is_zero(), 'ZERO_ADDRESS');
            assert(token_a_address != token_b_address, 'INVALID_ADDRESSES');

            let existing_pair = self.sv_pairs.read((base_address, quote_address, curve));
            //TODO: does this still work?
            assert(existing_pair.is_zero(), 'PAIR_EXISTS');

            let pair_class_hash = self.sv_pair_class_hash.read();

            let mut args = ArrayTrait::new();
            args.append(contract_address_to_felt252(base_address));
            args.append(contract_address_to_felt252(quote_address));
            args.append(class_hash_to_felt252(curve));

            let (pair_address, _) = deploy_syscall(pair_class_hash, 0, args.span(), false).unwrap();

            self.sv_pairs.write((base_address, quote_address, curve), pair_address);
            let index = self.sv_all_pairs_length.read();
            self.sv_pair_by_index.write(index, pair_address);
            self.sv_all_pairs_length.write(index + 1);

            return pair_address;
        }

        fn set_fee_to_address(ref self: ContractState, address: ContractAddress) {
            assert(get_caller_address() == self.sv_fee_to_setter_address.read(), 'FORBIDDEN');
            self.sv_fee_to_address.write(address);
        }

        fn set_fee_to_setter_address(ref self: ContractState, address: ContractAddress) {
            assert(get_caller_address() == self.sv_fee_to_setter_address.read(), 'FORBIDDEN');
            self.sv_fee_to_setter_address.write(address);
        }

        fn set_pair_class_hash(ref self: ContractState, pair_class_hash: ClassHash) {
            assert(get_caller_address() == self.sv_fee_to_setter_address.read(), 'FORBIDDEN');
            self.sv_pair_class_hash.write(pair_class_hash)
        }

        fn add_curve(ref self: ContractState, curve_class_hash: ClassHash) {
            assert(get_caller_address() == self.sv_fee_to_setter_address.read(), 'FORBIDDEN');
            self.sv_curve_class_hash.write(curve_class_hash, true);
        }

        fn get_balances(self: @ContractState, account: ContractAddress) -> Array<Balance> {
            let mut balances = ArrayTrait::new();
            let all_pairs_length = self.sv_all_pairs_length.read();
            let mut index = 0;
            loop {
                if index == all_pairs_length {
                    // TODO is this the correct break return val?
                    break 0;
                }

                let pair_address = self.sv_pair_by_index.read(index);
                let pair_balance = IERC20Dispatcher { contract_address: pair_address }.balance_of(account);

                let base_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.base_token();
                let base_balance = IERC20Dispatcher{ contract_address: base_address }.balance_of(account);
                let quote_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.quote_token();
                let quote_balance = IERC20Dispatcher{ contract_address: quote_address }.balance_of(account);

                let total_supply = IERC20Dispatcher { contract_address: pair_address }.total_supply();
                let (base_reserve, quote_reserve, _) = IStarkswapV1PairDispatcher { contract_address: pair_address }.get_reserves();

                balances.append(Balance {
                    pair_address,
                    pair_balance,
                    base_balance,
                    quote_balance,
                    total_supply,
                    base_reserve,
                    quote_reserve,
                });

                index = index + 1;
            };
            return balances;
        }

    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }

    #[generate_trait]
    #[external(v0)]
    impl UpgradeableContract of IUpgradeableContract {
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(impl_hash).unwrap();
            self.emit(Event::Upgraded(Upgraded { implementation: impl_hash }))
        }

        fn version(self: @ContractState) -> u8 {
            0
        }
    }
}

