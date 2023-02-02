



    u256,
    uint256_eq,
    uint256_lt,
    uint256_signed_div_rem,
)



// Number of iterations to run over Newton's method in order to find the y value that satisfies it
const STABLE_CURVE_ESTIMATION_ITERATIONS = 256;

#[view]
fn name() -> (name: felt) {
    return ('x3yy3xk',);
}

#[view]
fn get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_in: u256, reserve_in: u256, reserve_out: u256
) -> (amount_out: u256) {
    alloc_locals;

    let (r0) = SafeUint256.mul(amount_in, u256(997, 0));
    let (amount_in_minus_fee, _) = uint256_signed_div_rem(r0, u256(1000, 0));

    let (k: u256) = get_k(reserve_in, reserve_out);
    let (adjusted_x: u256) = SafeUint256.add(amount_in_minus_fee, reserve_in);
    let (required_y: u256) = _get_y(
        k, adjusted_x, reserve_out, STABLE_CURVE_ESTIMATION_ITERATIONS
    );

    let (amount_out) = SafeUint256.sub_le(reserve_out, required_y);
    return (amount_out,);
}

#[view]
fn get_amount_in{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_out: u256, reserve_in: u256, reserve_out: u256, fees_times_1k: felt
) -> (amount_in: u256) {
    alloc_locals;

    let (k: u256) = get_k(reserve_in, reserve_out);

    let (adjusted_x: u256) = SafeUint256.sub_le(reserve_out, amount_out);
    let (required_y: u256) = _get_y(
        k, adjusted_x, reserve_in, STABLE_CURVE_ESTIMATION_ITERATIONS
    );

    let (amount_in) = SafeUint256.sub_le(required_y, reserve_in);

    let (r0) = SafeUint256.mul(amount_in, u256(1003, 0));
    let (amount_in_plus_fee, _) = uint256_signed_div_rem(r0, u256(1000, 0));

    return (amount_in=amount_in_plus_fee);
}

#[view]
fn get_k{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    reserve_a: u256, reserve_b: u256
) -> (k: u256) {
    alloc_locals;
    let (base_pow2) = SafeUint256.mul(reserve_a, reserve_a);
    let (base_pow3) = SafeUint256.mul(reserve_a, base_pow2);
    let (A) = SafeUint256.mul(base_pow3, reserve_b);

    let (quote_pow2) = SafeUint256.mul(reserve_b, reserve_b);
    let (quote_pow3) = SafeUint256.mul(reserve_b, quote_pow2);
    let (B) = SafeUint256.mul(quote_pow3, reserve_a);

    let (k) = SafeUint256.add(A, B);
    return (k,);
}

// Compute derivative of x3y + y3x with regards to y
// The derivative is f'(x, y) = x^3 + 3 * y^2 * x
fn _derivative_x3y_y3x{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: u256, y: u256
) -> (res: u256) {
    alloc_locals;

    let (xy) = SafeUint256.mul(x, y);
    let (x2) = SafeUint256.mul(x, x);
    let (y2x) = SafeUint256.mul(xy, y);
    let (_3y2x) = SafeUint256.mul(y2x, u256(3, 0));
    let (x3) = SafeUint256.mul(x2, x);
    let (x3_3y2x) = SafeUint256.add(x3, _3y2x);

    return (res=x3_3y2x);
}

// @dev Get the new y based on the stable bonding curve (k=x3y+y3x) using Newton's method:
// https://en.wikipedia.org/wiki/Newton%27s_method
// @note Newton's method should get a closer estimation with every iteration since the derivative of k=x3y+y3x
// continuously increases (there are no local extrema/minima), therefore it should converge on an estimation
// of y that results in k being with a diff of at most 1 
// will not happen? If we can prove that this is the case, perhaps we could do away with the `iterations` param and loop
// until a sufficient y is found?
// Watch this: https://www.youtube.com/watch?v=zyXRo8Qjj0A&ab_channel=OscarVeliz
// Read this: https://en.wikipedia.org/wiki/Newton%27s_method#Practical_considerations
// @param k The k = x3y + y3x invariant of the curve
// @param x The x variable of the curve
// @param y0 A sufficiently close value to the result y, with which to start our search for the correct y
// @param iterations Number of times to iterate over Newton's method
// view function for testing
#[view]
fn _get_y{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    k: u256, x: u256, y0: u256, iterations: felt
) -> (y: u256) {
    alloc_locals;

    if (iterations == 0) {
        return (y=y0);
    }

    let (local current_k: u256) = get_k(x, y0);
    // TODO: Should we change this to diff <= 1 ??
    let (local k_equal_current_k: felt) = uint256_eq(current_k, k);
    if (k_equal_current_k != 0) {
        return (y=y0);
    }

    let (local _d: u256) = _derivative_x3y_y3x(x, y0);
    local numerator: u256;
    local dy: u256;
    local remainder: u256;
    local _y1: u256;
    local y1: u256;
    let (local current_k_lt_k: felt) = uint256_lt(current_k, k);

    // current_k < k
    if (current_k_lt_k == 1) {
        // dy = (k - current_k) / _d
        let (numerator) = SafeUint256.sub_le(k, current_k);
        let (dy, remainder) = SafeUint256.div_rem(numerator, _d);
        // y1 = y0 + dy
        let (_y1) = SafeUint256.add(y0, dy);

        // Return if there's no change in our y estimation (i.e. y0==y1)
        let (y0_eq_y1) = uint256_eq(y0, _y1);
        if (y0_eq_y1 == 1) {
            return (y=_y1);
        }

        // Need to get y1 again b/c reference revocation..
        let (y1) = SafeUint256.add(y0, dy);

        // current_k > k
    } else {
        // dy = (current_k - k) / _d
        let (numerator) = SafeUint256.sub_le(current_k, k);
        let (dy, remainder) = SafeUint256.div_rem(numerator, _d);
        // y1 = y0 - dy
        let (_y1) = SafeUint256.sub_le(y0, dy);

        // Return if there's no change in our y estimation (i.e. y0==y1)
        let (y0_eq_y1) = uint256_eq(y0, _y1);
        if (y0_eq_y1 == 1) {
            return (y=_y1);
        }

        // Need to get y1 again b/c reference revocation..
        let (y1) = SafeUint256.sub_le(y0, dy);
    }

    let (new_y) = _get_y(k, x, y1, iterations - 1);
    return (y=new_y);
}
