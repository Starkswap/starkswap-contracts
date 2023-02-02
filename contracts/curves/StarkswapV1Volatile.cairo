






#[view]
fn name() -> (name: felt) {
    return ('xyk',);
}

#[view]
fn get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_in: u256, reserve_in: u256, reserve_out: u256
) -> (amount_out: u256) {
    alloc_locals;

    // (a*997*B)/(A*1000+a*997)

    let (r0) = SafeUint256.mul(amount_in, u256(997, 0));
    let (numerator) = SafeUint256.mul(r0, reserve_out);
    let (r1) = SafeUint256.mul(reserve_in, u256(1000, 0));
    let (denominator) = SafeUint256.add(r1, r0);

    let (amount_out, _) = uint256_signed_div_rem(numerator, denominator);

    return (amount_out,);
}

#[view]
fn get_amount_in{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_out: u256, reserve_in: u256, reserve_out: u256
) -> (amount_in: u256) {
    alloc_locals;

    // (A*b*1000)/((B-b)*997) + 1

    let (r0) = SafeUint256.mul(reserve_in, amount_out);
    let (numerator) = SafeUint256.mul(r0, u256(1000, 0));
    let (r1) = SafeUint256.sub_le(reserve_out, amount_out);
    let (denominator) = SafeUint256.mul(r1, u256(997, 0));

    let (r2, _) = uint256_signed_div_rem(numerator, denominator);
    let (amount_in: u256) = SafeUint256.add(r2, u256(1, 0));

    return (amount_in,);
}

#[view]
fn get_k{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    reserve_a: u256, reserve_b: u256
) -> (k: u256) {
    let (k) = SafeUint256.mul(reserve_a, reserve_b);
    return (k,);
}
