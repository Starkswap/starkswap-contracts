#[abi]
trait IStarkswapV1Curve {
    fn name() -> felt252;

    fn get_amount_out(amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256;

    fn get_amount_in(amount_out: u256, reserve_in: u256, reserve_out: u256) -> u256;

    fn get_k(reserve_a: u256, reserve_b: u256) -> u256;
}
