#[starknet::interface]
trait IStarkswapV1Curve<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn get_amount_out(self: @TContractState, amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256;
    fn get_amount_in(self: @TContractState, amount_out: u256, reserve_in: u256, reserve_out: u256, fees_times_1k: felt252) -> u256;
    fn get_k(self: @TContractState, reserve_a: u256, reserve_b: u256) -> u256;
}
