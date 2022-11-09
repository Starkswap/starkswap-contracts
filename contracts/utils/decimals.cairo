%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.pow import pow
from openzeppelin.security.safemath.library import SafeUint256

const DECIMAL_18_NORMALISER = 1000000000000000000;

func make_18_dec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: Uint256, decimals: felt
) -> (value_18_dec: Uint256) {
    alloc_locals;
    if (decimals == 18) {
        return (value,);
    } else {
        let (decimal_scaler) = pow(10, decimals);
        let (r0) = SafeUint256.mul(value, Uint256(DECIMAL_18_NORMALISER, 0));
        let (normalised_value, _) = SafeUint256.div_rem(r0, Uint256(decimal_scaler, 0));

        return (normalised_value,);
    }
}

func unmake_18_dec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: Uint256, decimals: felt
) -> (value: Uint256) {
    alloc_locals;
    if (decimals == 18) {
        return (value,);
    } else {
        let (decimal_scaler) = pow(10, decimals);
        let (r0) = SafeUint256.mul(value, Uint256(decimal_scaler, 0));
        let (normalised_value, _) = SafeUint256.div_rem(r0, Uint256(DECIMAL_18_NORMALISER, 0));

        return (normalised_value,);
    }
}
