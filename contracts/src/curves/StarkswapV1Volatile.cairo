#[starknet::contract]
mod StarkswapV1Volatile {
    use integer::u256_from_felt252;

    #[storage]
    struct Storage {
    }

    #[external(v0)]
    impl StarkswapV1Volatile of starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1Curve<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            return 'xyk';
        }

        fn get_amount_out(self: @ContractState, amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256 {
            // (a*997*B)/(A*1000+a*997)
            return (amount_in * u256_from_felt252(997) * reserve_out)
                / (reserve_in * u256_from_felt252(1000) + amount_in * u256_from_felt252(997));
        }

        fn get_amount_in(self: @ContractState, amount_out: u256, reserve_in: u256, reserve_out: u256, fees_times_1k: felt252) -> u256 {
            // (A*b*1000)/((B-b)*997) + 1

            return ((reserve_in * amount_out * u256_from_felt252(1000))
                / ((reserve_out - amount_out) * u256_from_felt252(997)))
                + u256_from_felt252(1);
        }

        fn get_k(self: @ContractState, reserve_a: u256, reserve_b: u256) -> u256 {
            return reserve_a * reserve_b;
        }
    }
}
