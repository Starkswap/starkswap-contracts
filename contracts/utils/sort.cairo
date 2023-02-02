



fn _sort_tokens{range_check_ptr}(
    token_a_address: felt,
    token_b_address: felt
    ) -> (base_address: felt, quote_address: felt) {

    let res = is_le_felt(token_a_address, token_b_address);
    if (res == TRUE) {
        return (token_a_address, token_b_address);
    }
    return (token_b_address, token_a_address);
}

fn _sort_amounts{range_check_ptr}(
    token_a_address: felt,
    base_token_address: felt,
    amount_0: u256,
    amount_1: u256) -> (amount_a: u256, amount_b: u256) {

    if (base_token_address == token_a_address) {
        return (amount_0, amount_1);
    }

    return (amount_1, amount_0);
}
