use starknet::ContractAddress;

#[derive(Serde, Copy, Drop, storage_access::StorageAccess)]
struct Token {
    address: ContractAddress,
    name: felt252,
    symbol: felt252,
    decimals: u8,
}
