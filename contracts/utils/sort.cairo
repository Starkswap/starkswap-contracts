from starkware.cairo.common.math_cmp import (is_le_felt, is_le)
from starkware.cairo.common.bool import (TRUE, FALSE)
from starkware.cairo.common.uint256 import Uint256

func _sort_tokens{range_check_ptr}(
    token_a_address: felt,
    token_b_address: felt
    ) -> (base_address: felt, quote_address: felt) {

    let res = is_le_felt(token_a_address, token_b_address);
    if (res == TRUE) {
        return (token_a_address, token_b_address);
    }
    return (token_b_address, token_a_address);
}

func _sort_amounts{range_check_ptr}(
    token_a_address: felt,
    base_token_address: felt,
    amount_0: Uint256,
    amount_1: Uint256) -> (amount_a: Uint256, amount_b: Uint256) {

    if (base_token_address == token_a_address) {
        return (amount_0, amount_1);
    }

    return (amount_1, amount_0);
}
