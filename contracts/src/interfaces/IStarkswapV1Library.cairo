#[starknet::interface]
trait IStarkswapV1Library<TContractState> {
    fn sortTokens(self: @TContractState, token_a_address: felt252, token_b_address: felt252) -> (felt252, felt252);
    fn pairFor(
    self: @TContractState,
        factory_address: felt252,
        pair_class_hash: felt252,
        token_a_address: felt252,
        token_b_address: felt252,
        curve: felt252
    ) -> felt252;
    fn get_reserves(
    self: @TContractState,
        factory_address: felt252,
        pair_class_hash: felt252,
        token_a_address: felt252,
        token_b_address: felt252,
        curve: felt252
    ) -> (u256, u256);
    fn quote(self: @TContractState, amount_a: u256, reserve_a: u256, reserve_b: u256, curve: felt252) -> u256;
    fn get_amount_out(
        self: @TContractState, amount_out: u256, reserve_in: u256, reserve_out: u256, curve: felt252
    ) -> u256;
    fn get_amount_in(self: @TContractState, amount_out: u256, reserve_in: u256, reserve_out: u256, curve: felt252) -> u256;
    fn get_amounts_out(
        self: @TContractState,
        factory_address: felt252,
        pair_class_hash: felt252,
        amount_in: u256,
        path_len: felt252,
        path: Array<felt252>,
        curves_len: felt252,
        curves: Array<felt252>
    ) -> (felt252, Array<u256>);
    fn get_amounts_in(
        self: @TContractState,
        factory_address: felt252,
        pair_class_hash: felt252,
        amount_in: u256,
        path_len: felt252,
        path: Array<felt252>,
        curves_len: felt252,
        curves: Array<felt252>
    ) -> (felt252, Array<u256>);
}