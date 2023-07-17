use starknet::ContractAddress;
use starknet::ClassHash;
use starkswap_contracts::structs::balance::Balance;
use starkswap_contracts::structs::pair::Pair;

#[abi]
trait IStarkswapV1Factory {
    fn fee_to_address() -> ContractAddress;
    fn pair_class_hash() -> ClassHash;
    fn fee_to_setter_address() -> ContractAddress;
    fn curve_class_hash(curve_class_hash: ClassHash) -> bool;
    fn get_pair(
        token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
    ) -> ContractAddress;
    fn all_pairs(index: u64) -> ContractAddress;
    fn all_pairs_length() -> u64;
    fn get_all_pairs() -> Array<Pair>;
    fn create_pair(
        token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash
    ) -> ContractAddress;
    fn set_fee_to_address(address: ContractAddress);
    fn set_fee_to_setter_address(address: ContractAddress);
    fn set_pair_class_hash(pair_class_hash: ClassHash);
    fn add_curve_class_hash(curve_class_hash: ClassHash);
    fn get_balances(account: ContractAddress) -> Array<Balance>;
}
