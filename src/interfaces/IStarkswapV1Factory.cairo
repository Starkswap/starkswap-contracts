use starknet::ContractAddress;
use starknet::ClassHash;
use starkswap_contracts::structs::balance::Balance;
use starkswap_contracts::structs::pair::Pair;

#[abi]
trait IStarkswapV1Factory {
    fn feeTo() -> ContractAddress;
    fn pairClassHash() -> ClassHash;
    fn feeToSetter() -> ContractAddress;
    fn getCurve(curve_class_hash: ClassHash) -> ClassHash;
    fn getPair(token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash) -> ContractAddress;
    fn allPairs(index: felt252) -> felt252;
    fn allPairsLength() -> felt252;
    fn getAllPairs() -> Array<Pair>;
    fn createPair(token_a_address: ContractAddress, token_b_address: ContractAddress, curve: ClassHash) -> ContractAddress;
    fn setFeeTo(address: ContractAddress) -> ContractAddress;
    fn setFeeToSetter(address: ContractAddress) -> ContractAddress;
    fn setPairClassHash(pair_class_hash: ClassHash) -> ClassHash;
    fn addCurve(curve_class_hash: ClassHash) -> ClassHash;
    fn getBalances(account: ContractAddress) -> Array<Balance>;
}
