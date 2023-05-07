use starknet::ContractAddress;
use starknet::ClassHash;

#[derive(Serde, Copy, Drop)]
struct Route {
    input: ContractAddress,
    output: ContractAddress,
    curve: ClassHash,
}
