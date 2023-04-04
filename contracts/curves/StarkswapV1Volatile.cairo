%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_signed_div_rem
from contracts.utils.uint import assert_uint256_zero, assert_uint256_gt
from openzeppelin.security.safemath.library import SafeUint256

@view
func name() -> (name: felt) {
    return ('xyk',);
}

@view
func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_in: Uint256, reserve_in: Uint256, reserve_out: Uint256
) -> (amount_out: Uint256) {
    alloc_locals;

    // (a*997*B)/(A*1000+a*997)

    let (r0) = SafeUint256.mul(amount_in, Uint256(997, 0));
    let (numerator) = SafeUint256.mul(r0, reserve_out);
    let (r1) = SafeUint256.mul(reserve_in, Uint256(1000, 0));
    let (denominator) = SafeUint256.add(r1, r0);

    let (amount_out, _) = uint256_signed_div_rem(numerator, denominator);

    return (amount_out,);
}

@view
func get_amount_in{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_out: Uint256, reserve_in: Uint256, reserve_out: Uint256
) -> (amount_in: Uint256) {
    alloc_locals;

    // (A*b*1000)/((B-b)*997) + 1

    let (r0) = SafeUint256.mul(reserve_in, amount_out);
    let (numerator) = SafeUint256.mul(r0, Uint256(1000, 0));
    let (r1) = SafeUint256.sub_le(reserve_out, amount_out);
    let (denominator) = SafeUint256.mul(r1, Uint256(997, 0));

    let (r2, _) = uint256_signed_div_rem(numerator, denominator);
    let (amount_in: Uint256) = SafeUint256.add(r2, Uint256(1, 0));

    return (amount_in,);
}

@view
func get_k{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    reserve_a: Uint256, reserve_b: Uint256
) -> (k: Uint256) {
    let (k) = SafeUint256.mul(reserve_a, reserve_b);
    return (k,);
}
