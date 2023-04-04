%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_lt,
    uint256_signed_div_rem,
    uint256_mul,
    uint256_add,
    uint256_sub
)
from contracts.utils.uint import assert_uint256_zero
from openzeppelin.security.safemath.library import SafeUint256

// Number of iterations to run over Newton's method in order to find the y value that satisfies it
const STABLE_CURVE_ESTIMATION_ITERATIONS = 256;
const DECIMALS_NORMALISER_18 = 1000000000000000000;

@view
func name() -> (name: felt) {
    return ('x3yy3xk',);
}

@view
func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_in: Uint256, reserve_in: Uint256, reserve_out: Uint256
) -> (amount_out: Uint256) {
    alloc_locals;

    let (r0) = SafeUint256.mul(amount_in, Uint256(997, 0));
    let (amount_in_minus_fee, _) = uint256_signed_div_rem(r0, Uint256(1000, 0));

    let (k: Uint256) = get_k(reserve_in, reserve_out);
    let (adjusted_x: Uint256) = SafeUint256.add(amount_in_minus_fee, reserve_in);
    let (required_y: Uint256) = _get_y(
        k, adjusted_x, reserve_out, STABLE_CURVE_ESTIMATION_ITERATIONS
    );

    let (amount_out) = SafeUint256.sub_le(reserve_out, required_y);
    return (amount_out,);
}

@view
func get_amount_in{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_out: Uint256, reserve_in: Uint256, reserve_out: Uint256, fees_times_1k: felt
) -> (amount_in: Uint256) {
    alloc_locals;

    let (k: Uint256) = get_k(reserve_in, reserve_out);

    let (adjusted_x: Uint256) = SafeUint256.sub_le(reserve_out, amount_out);
    let (required_y: Uint256) = _get_y(
        k, adjusted_x, reserve_in, STABLE_CURVE_ESTIMATION_ITERATIONS
    );

    let (amount_in) = SafeUint256.sub_le(required_y, reserve_in);

    let (r0) = SafeUint256.mul(amount_in, Uint256(1003, 0));
    let (amount_in_plus_fee, _) = uint256_signed_div_rem(r0, Uint256(1000, 0));

    return (amount_in=amount_in_plus_fee);
}

@view
func get_k{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    reserve_a: Uint256, reserve_b: Uint256
) -> (k: Uint256) {
    alloc_locals;

    let (a0, _) = uint256_mul(reserve_a, reserve_b);
    let (_a, _) = uint256_signed_div_rem(a0, Uint256(DECIMALS_NORMALISER_18, 0));

    let (a_pow2, _) = uint256_mul(reserve_a, reserve_a);
    let (a2, _)     = uint256_signed_div_rem(a_pow2, Uint256(DECIMALS_NORMALISER_18, 0));

    let (b_pow2, _) = uint256_mul(reserve_b, reserve_b);
    let (b2, _)     = uint256_signed_div_rem(b_pow2, Uint256(DECIMALS_NORMALISER_18, 0));

    let (_b, _) = uint256_add(a2, b2);
    let (_k, _) = uint256_mul(_a, _b);
    let (k, _)  = uint256_signed_div_rem(_k, Uint256(DECIMALS_NORMALISER_18, 0));
    return (k,);
}

func _derivative_x3y_y3x{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Uint256, y: Uint256
) -> (res: Uint256) {
    alloc_locals;

    let (y2, _)    = uint256_mul(y, y);
    let (y2_18, _) = uint256_signed_div_rem(y2, Uint256(DECIMALS_NORMALISER_18, 0));

    let (a0, _)    = uint256_mul(x, y2_18);
    let (a1, _)    = uint256_mul(a0, Uint256(3, 0));
    let (_3xy2, _) = uint256_signed_div_rem(a1, Uint256(DECIMALS_NORMALISER_18, 0));

    let (x2, _)    = uint256_mul(x, x);
    let (x2_18, _) = uint256_signed_div_rem(x2, Uint256(DECIMALS_NORMALISER_18, 0));
    let (x3, _)    = uint256_mul(x2_18, x);
    let (_x3, _)   = uint256_signed_div_rem(x3, Uint256(DECIMALS_NORMALISER_18, 0));

    let (x3_3y2x, _) = uint256_add(_x3, _3xy2);
    return (res=x3_3y2x);
}

@view
func _get_y{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    k: Uint256, x: Uint256, y0: Uint256, iterations: felt
) -> (y: Uint256) {
    alloc_locals;

    if (iterations == 0) {
        return (y=y0);
    }

    let (current_k: Uint256) = get_k(x, y0);
    // TODO: Should we change this to diff <= 1 ??
    let (k_equal_current_k: felt) = uint256_eq(current_k, k);
    if (k_equal_current_k != 0) {
        return (y=y0);
    }

    let (_d: Uint256) = _derivative_x3y_y3x(x, y0);    
    let (current_k_lt_k: felt) = uint256_lt(current_k, k);

    // current_k < k
    if (current_k_lt_k == 1) {
        // dy = (k - current_k) / _d
        let (numerator) = uint256_sub(k, current_k);
        let (numerator, _) = uint256_mul(numerator, Uint256(DECIMALS_NORMALISER_18, 0));
        let (dy, _) = uint256_signed_div_rem(numerator, _d);
        // y1 = y0 + dy
        let (_y1, _) = uint256_add(y0, dy);

        // Return if there's no change in our y estimation (i.e. y0==y1)
        let (y0_eq_y1) = uint256_eq(y0, _y1);
        if (y0_eq_y1 == 1) {
            return (y=_y1);
        }

        // Need to get y1 again b/c reference revocation..
        let (y1, _) = uint256_add(y0, dy);
        return _get_y(k, x, y1, iterations - 1);
        // current_k > k
    } else {
        // dy = (current_k - k) / _d
        let (numerator) = uint256_sub(current_k, k);
        let (numerator, _) = uint256_mul(numerator, Uint256(DECIMALS_NORMALISER_18, 0));
        let (dy, _) = uint256_signed_div_rem(numerator, _d);
        // y1 = y0 - dy
        let (_y1) = uint256_sub(y0, dy);

        // Return if there's no change in our y estimation (i.e. y0==y1)
        let (y0_eq_y1) = uint256_eq(y0, _y1);
        if (y0_eq_y1 == 1) {
            return (y=_y1);
        }

        // Need to get y1 again b/c reference revocation..
        let (y1) = uint256_sub(y0, dy);
        return _get_y(k, x, y1, iterations - 1);
    }
}
