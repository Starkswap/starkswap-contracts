use starknet::ContractAddress;
use starknet::ClassHash;
use starkswap_contracts::structs::balance::Balance;
use starkswap_contracts::structs::pair::Pair;

#[starknet::interface]
trait IStarkswapV1Factory<TContractState> {
    fn fee_to_address(self: @TContractState) -> ContractAddress;
    fn pair_class_hash(self: @TContractState) -> ClassHash;
    fn fee_to_setter_address(self: @TContractState) -> ContractAddress;
    fn curve_class_hash(self: @TContractState, curve_class_hash: ClassHash) -> bool;
    fn get_pair(
        self: @TContractState, token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
    ) -> ContractAddress;
    fn all_pairs(self: @TContractState, index: u64) -> ContractAddress;
    fn all_pairs_length(self: @TContractState, ) -> u64;
    fn get_all_pairs(self: @TContractState, ) -> Array<Pair>;
    fn create_pair(
        ref self: TContractState, token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
    ) -> ContractAddress;
    fn set_fee_to_address(ref self: TContractState, address: ContractAddress);
    fn set_fee_to_setter_address(ref self: TContractState, address: ContractAddress);
    fn set_pair_class_hash(ref self: TContractState, pair_class_hash: ClassHash);
    fn add_curve(ref self: TContractState, curve_class_hash: ClassHash);
    fn get_balances(self: @TContractState, account: ContractAddress) -> Array<Balance>;
}
