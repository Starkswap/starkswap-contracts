






const DECIMAL_18_NORMALISER = 1000000000000000000;

fn make_18_dec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: u256, decimals: felt
) -> (value_18_dec: u256) {
    alloc_locals;
    if (decimals == 18) {
        return (value,);
    } else {
        let (decimal_scaler) = pow(10, decimals);
        let (r0) = SafeUint256.mul(value, u256(DECIMAL_18_NORMALISER, 0));
        let (normalised_value, _) = SafeUint256.div_rem(r0, u256(decimal_scaler, 0));

        return (normalised_value,);
    }
}

fn unmake_18_dec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: u256, decimals: felt
) -> (value: u256) {
    alloc_locals;
    if (decimals == 18) {
        return (value,);
    } else {
        let (decimal_scaler) = pow(10, decimals);
        let (r0) = SafeUint256.mul(value, u256(decimal_scaler, 0));
        let (normalised_value, _) = SafeUint256.div_rem(r0, u256(DECIMAL_18_NORMALISER, 0));

        return (normalised_value,);
    }
}
