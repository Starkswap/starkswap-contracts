from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_lt, uint256_le
from starkware.cairo.common.bool import TRUE, FALSE

func assert_uint256_zero{range_check_ptr}(val: Uint256) {
    let (is_zero) = uint256_eq(val, Uint256(0, 0));
    assert is_zero = TRUE;
    return ();
}

func assert_uint256_gt{range_check_ptr}(a: Uint256, b: Uint256) {
    let (is_gt) = uint256_lt(b, a);
    assert is_gt = TRUE;
    return ();
}

func assert_uint256_ge{range_check_ptr}(a: Uint256, b: Uint256) {
    let (is_ge) = uint256_le(b, a);
    assert is_ge = TRUE;
    return ();
}
