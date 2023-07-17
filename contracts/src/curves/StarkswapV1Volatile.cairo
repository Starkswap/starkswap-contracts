#[contract]
mod StarkswapV1Volatile {
    use integer::u256_from_felt252;

    #[view]
    fn name() -> felt252 {
        return 'xyk';
    }

    #[view]
    fn get_amount_out(amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256 {
        // (a*997*B)/(A*1000+a*997)
        return (amount_in * u256_from_felt252(997) * reserve_out)
            / (reserve_in * u256_from_felt252(1000) + amount_in * u256_from_felt252(997));
    }

    #[view]
    fn get_amount_in(amount_out: u256, reserve_in: u256, reserve_out: u256) -> u256 {
        // (A*b*1000)/((B-b)*997) + 1

        return ((reserve_in * amount_out * u256_from_felt252(1000))
            / ((reserve_out - amount_out) * u256_from_felt252(997)))
            + u256_from_felt252(1);
    }

    #[view]
    fn get_k(reserve_a: u256, reserve_b: u256) -> u256 {
        return reserve_a * reserve_b;
    }
}