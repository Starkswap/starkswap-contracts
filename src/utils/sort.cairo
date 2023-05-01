use starknet::ContractAddress;

fn _sort_tokens(
    token_a_address: ContractAddress, token_b_address: ContractAddress
) -> (ContractAddress, ContractAddress) implicits(RangeCheck) {
    //TODO: find out how to compare contract addresses
    //if (token_a_address <= token_b_address) {
    //return (token_a_address, token_b_address);
    //}
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
