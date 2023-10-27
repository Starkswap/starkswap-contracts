use starknet::ContractAddress;
use starknet::ClassHash;

#[derive(Serde, Copy, Drop, storage_access::StorageAccess)]
struct Route {
    input: ContractAddress,
    output: ContractAddress,
    curve: ClassHash,
}
