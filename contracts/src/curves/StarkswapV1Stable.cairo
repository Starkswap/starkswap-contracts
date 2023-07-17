#[contract]
mod StarkswapV1Stable {
    use integer::u256_from_felt252;

    // Number of iterations to run over Newton's method in order to find the y value that satisfies it
    const STABLE_CURVE_ESTIMATION_ITERATIONS: felt252 = 256;

    #[view]
    fn name() -> felt252 {
        return 'x3yy3xk';
    }

    #[view]
    fn get_amount_out(amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256 {
        let amount_in_minus_fee = amount_in * u256_from_felt252(997) / u256_from_felt252(1000);

        let k = get_k(reserve_in, reserve_out);
        let adjusted_x: u256 = amount_in_minus_fee + reserve_in;
        let required_y: u256 = _get_y(k, adjusted_x, reserve_out, STABLE_CURVE_ESTIMATION_ITERATIONS);

        return reserve_out - required_y;
    }

    #[view]
    fn get_amount_in(
        amount_out: u256, reserve_in: u256, reserve_out: u256, fees_times_1k: felt252
    ) -> u256 {
        let k: u256 = get_k(reserve_in, reserve_out);

        let adjusted_x: u256 = reserve_out - amount_out;
        let required_y: u256 = _get_y(k, adjusted_x, reserve_in, STABLE_CURVE_ESTIMATION_ITERATIONS);

        let amount_in = required_y - reserve_in;

        let r0 = amount_in * u256_from_felt252(1003);
        let amount_in_plus_fee = r0 / u256_from_felt252(1000);

        return amount_in_plus_fee;
    }

    #[view]
    fn get_k(reserve_a: u256, reserve_b: u256) -> u256 {
        let A = (reserve_a * reserve_a * reserve_a) * reserve_b;
        let B = (reserve_b * reserve_b * reserve_b) * reserve_a;
        return A + B;
    }

    // Compute derivative of x3y + y3x with regards to y
    // The derivative is f'(x, y) = x^3 + 3 * y^2 * x
    fn _derivative_x3y_y3x(x: u256, y: u256) -> u256 {
        return (x * x * x) + u256_from_felt252(3) * y * y * x;
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
    fn _get_y(k: u256, x: u256, y0: u256, iterations: felt252) -> u256 {
        if (iterations == 0) {
            return y0;
        }

        let current_k: u256 = get_k(x, y0);
        // TODO: Should we change this to diff <= 1 ??
        if (current_k == k) {
            return y0;
        }

        let _d: u256 = _derivative_x3y_y3x(x, y0);
        if (current_k < k) {
            // dy = (k - current_k) / _d
            let dy = (k - current_k) / _d;
            // y1 = y0 + dy
            let _y1 = y0 + dy;

            // Return if there's no change in our y estimation (i.e. y0==y1)
            if (y0 == _y1) {
                return _y1;
            }

            // Need to get y1 again b/c reference revocation..
            let y1 = _y1;
            return _get_y(k, x, y1, iterations - 1);
            // current_k > k
        } else {
            // dy = (current_k - k) / _d
            let dy = (current_k - k) / _d;
            // y1 = y0 - dy
            let _y1 = y0 - dy;

            // Return if there's no change in our y estimation (i.e. y0==y1)
            if (y0 == _y1) {
                return _y1;
            }

            // Need to get y1 again b/c reference revocation..
            let y1 = y0 - dy;
            return _get_y(k, x, y1, iterations - 1);
        }
    }
}