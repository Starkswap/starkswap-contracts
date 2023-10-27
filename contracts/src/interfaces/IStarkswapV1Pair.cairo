use starkswap_contracts::structs::observation::Observation;
use starknet::ClassHash;
use starknet::ContractAddress;

#[starknet::interface]
trait IStarkswapV1Pair<TContractState> {
    fn factory(self: @TContractState) -> ContractAddress;
    fn base_token(self: @TContractState) -> ContractAddress;
    fn quote_token(self: @TContractState) -> ContractAddress;
    fn curve(self: @TContractState) -> (ClassHash, felt252);
    fn get_reserves(self: @TContractState) -> (u256, u256, u64);
    fn get_observations(self: @TContractState, num_observations: felt252) -> Array<Observation>;
    fn last_observation(self: @TContractState) -> Observation;
    fn k_last(self: @TContractState) -> u256;
    fn mint(ref self: TContractState, to: ContractAddress) -> u256;
    fn burn(ref self: TContractState, to: ContractAddress) -> (u256, u256);
    fn swap(
        ref self: TContractState,
        base_amount_out: u256,
        quote_amount_out: u256,
        to: ContractAddress,
        calldata: Array<felt252>
    );
    fn skim(ref self: TContractState, to: ContractAddress);
    fn sync(ref self: TContractState);
}
