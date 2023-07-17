#[contract]
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
    use hash::LegacyHash;
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

    // TODO: workaround for supporting LegacyMap ClassHash keys
    impl LegacyHashClassHash of LegacyHash<ClassHash> {
        fn hash(state: felt252, value: ClassHash) -> felt252 {
            LegacyHash::<felt252>::hash(state, value.into())
        }
    }

    #[constructor]
    fn constructor(fee_to_setter_address: ContractAddress, pair_class_hash: ClassHash) {
        assert(!fee_to_setter_address.is_zero(), 'ZERO_FEE_TO_SETTER_ADDRESS');
        assert(!pair_class_hash.is_zero(), 'ZERO_PAIR_CLASS_HASH');
        sv_fee_to_setter_address::write(fee_to_setter_address);
        sv_pair_class_hash::write(pair_class_hash);
    }

    #[view]
    fn fee_to_address() -> ContractAddress {
        return sv_fee_to_address::read();
    }

    #[view]
    fn pair_class_hash() -> ClassHash {
        return sv_pair_class_hash::read();
    }

    #[view]
    fn fee_to_setter_address() -> ContractAddress {
        return sv_fee_to_setter_address::read();
    }

    #[view]
    fn curve_class_hash(curve_class_hash: ClassHash) -> bool {
        return sv_curve_class_hash::read(curve_class_hash);
    }

    #[view]
    fn get_pair(
        token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
    ) -> ContractAddress {
        let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
        return sv_pairs::read((base_address, quote_address, curve));
    }

    #[view]
    fn all_pairs(index: u64) -> ContractAddress {
        assert(index < all_pairs_length(), 'INVALID_INDEX');
        return sv_pair_by_index::read(index);
    }

    #[view]
    fn all_pairs_length() -> u64 {
        return sv_all_pairs_length::read();
    }

    #[view]
    fn get_all_pairs() -> Array<Pair> {
        let mut pairs = ArrayTrait::new();
        let all_pairs_length = all_pairs_length();
        let mut index = 0;
        loop {
            if index == all_pairs_length {
                // TODO is this the correct break return val?
                break 0;
            }

            let pair_address = sv_pair_by_index::read(index);
            let base_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.base_token();
            let quote_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.quote_token();
            let (curve, _) = IStarkswapV1PairDispatcher { contract_address: pair_address }.curve();

            let pair_name = IStarkswapV1PairDispatcher { contract_address: pair_address }.name();
            let pair_symbol = IStarkswapV1PairDispatcher { contract_address: pair_address }.symbol();
            let pair_decimals = IStarkswapV1PairDispatcher { contract_address: pair_address }.decimals();
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

    #[external]
    fn create_pair(
        token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
    ) -> ContractAddress {

        assert(curve_class_hash(curve) == true, 'INVALID_CURVE');
        assert(token_a_address != token_b_address, 'INVALID_ADDRESSES');

        let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);

        assert(!base_address.is_zero(), 'ZERO_ADDRESS');
        assert(token_a_address != token_b_address, 'INVALID_ADDRESSES');

        let existing_pair = sv_pairs::read((base_address, quote_address, curve));
        //TODO: does this still work?
        assert(existing_pair.is_zero(), 'PAIR_EXISTS');

        let pair_class_hash = sv_pair_class_hash::read();

        let mut args = ArrayTrait::new();
        args.append(contract_address_to_felt252(base_address));
        args.append(contract_address_to_felt252(quote_address));
        args.append(class_hash_to_felt252(curve));

        let (pair_address, _) = deploy_syscall(pair_class_hash, 0, args.span(), false).unwrap_syscall();

        sv_pairs::write((base_address, quote_address, curve), pair_address);
        let index = sv_all_pairs_length::read();
        sv_pair_by_index::write(index, pair_address);
        sv_all_pairs_length::write(index + 1);

        return pair_address;
    }

    #[external]
    fn set_fee_to_address(fee_to_address: ContractAddress) {
        assert(get_caller_address() == fee_to_setter_address(), 'FORBIDDEN');
        sv_fee_to_address::write(fee_to_address);
    }

    #[external]
    fn set_fee_to_setter_address(fee_to_setter_address: ContractAddress) {
        assert(get_caller_address() == fee_to_setter_address(), 'FORBIDDEN');
        sv_fee_to_setter_address::write(fee_to_setter_address);
    }

    #[external]
    fn set_pair_class_hash(pair_class_hash: ClassHash) {
        assert(get_caller_address() == fee_to_setter_address(), 'FORBIDDEN');
        sv_pair_class_hash::write(pair_class_hash)
    }

    #[external]
    fn add_curve_class_hash(curve_class_hash: ClassHash) {
        assert(get_caller_address() == fee_to_setter_address(), 'FORBIDDEN');
        sv_curve_class_hash::write(curve_class_hash, true);
    }

    #[view]
    fn get_balances(account: ContractAddress) -> Array<Balance> {
        let mut balances = ArrayTrait::new();
        let all_pairs_length = all_pairs_length();
        let mut index = 0;
        loop {
            if index == all_pairs_length {
                // TODO is this the correct break return val?
                break 0;
            }

            let pair_address = sv_pair_by_index::read(index);
            let pair_balance = IStarkswapV1PairDispatcher { contract_address: pair_address }.balance_of(account);

            let base_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.base_token();
            let base_balance = IERC20Dispatcher{ contract_address: base_address }.balance_of(account);
            let quote_address = IStarkswapV1PairDispatcher { contract_address: pair_address }.quote_token();
            let quote_balance = IERC20Dispatcher{ contract_address: quote_address }.balance_of(account);

            let total_supply = IStarkswapV1PairDispatcher { contract_address: pair_address }.total_supply();
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

