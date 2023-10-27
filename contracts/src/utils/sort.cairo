use starknet::ContractAddress;
use starknet::contract_address_to_felt252;
use integer::u256_from_felt252;

fn _sort_tokens(
    token_a_address: ContractAddress, token_b_address: ContractAddress
) -> (ContractAddress, ContractAddress) implicits(RangeCheck) {
    let token_a_address_felt = contract_address_to_felt252(token_a_address);
    let token_b_address_felt = contract_address_to_felt252(token_b_address);

    if (u256_from_felt252(token_a_address_felt) <= u256_from_felt252(token_b_address_felt)) {
        return (token_a_address, token_b_address);
    }
    return (token_b_address, token_a_address);
}

fn _sort_amounts(
    token_a_address: ContractAddress,
    base_token_address: ContractAddress,
    amount_0: u256,
    amount_1: u256
) -> (u256, u256) implicits(RangeCheck) {
    if (base_token_address == token_a_address) {
        return (amount_0, amount_1);
    }

    return (amount_1, amount_0);
}
