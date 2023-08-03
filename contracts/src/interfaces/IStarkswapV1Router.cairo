use starkswap_contracts::structs::route::Route;
use starknet::ContractAddress;
use starknet::ClassHash;

#[starknet::interface]
trait IStarkswapV1Router<TContractState> {
    fn factory(self: @TContractState) -> ContractAddress;
    fn pair_class_hash(self: @TContractState) -> ClassHash;
    fn add_liquidity(
        self: @TContractState,
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: felt252,
    ) -> (u256, u256, u256);
    fn remove_liquidity(
        self: @TContractState,
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash,
        liquidity: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: felt252,
    ) -> (u256, u256);
    fn swap_exact_tokens_for_tokens(
        self: @TContractState, amount_in: u256, amount_out_min: u256, routes: Array<Route>, to: ContractAddress, deadline: felt252, 
    ) -> Array<u256>;
    fn swap_tokens_for_exact_tokens(
        self: @TContractState, amount_out: u256, amount_in_max: u256, routes: Array<Route>, to: ContractAddress, deadline: felt252, 
    ) -> Array<u256>;
    fn quote(self: @TContractState, amount_a: u256, reserve_a: u256, reserve_b: u256, ) -> u256;
    fn oracle_quote(
        self: @TContractState,
        pair_address: ContractAddress,
        token_in: ContractAddress,
        amount_in: u256,
        sample_count: felt252
    ) -> u256;
    fn get_amount_out(
        self: @TContractState,
        amount_in: u256,
        reserve_in: u256,
        reserve_out: u256,
        decimals_in: u8,
        decimals_out: u8,
        curve: ClassHash
    ) -> u256;
    fn get_amount_in(
        self: @TContractState,
        amount_out: u256,
        reserve_in: u256,
        reserve_out: u256,
        decimals_in: u8,
        decimals_out: u8,
        curve: ClassHash
    ) -> u256;
    fn get_amounts_out(self: @TContractState, amount_in: u256, routes: Array<Route>) -> Array<u256>;
    fn get_amounts_in(self: @TContractState, amount_out: u256, routes: Array<Route>) -> Array<u256>;
}
