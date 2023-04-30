use starknet::ContractAddress;

#[derive(Serde, Copy, Drop)]
struct Token {
     address: ContractAddress,
     name: felt252,
     symbol: felt252,
     decimals: felt252,
 }
