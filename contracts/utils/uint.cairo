


fn assert_uint256_zero{range_check_ptr}(val: u256) {
    let (is_zero) = uint256_eq(val, u256(0, 0));
    assert is_zero = TRUE;
    return ();
}

fn assert_uint256_gt{range_check_ptr}(a: u256, b: u256) {
    let (is_gt) = uint256_lt(b, a);
    assert is_gt = TRUE;
    return ();
}

fn assert_uint256_ge{range_check_ptr}(a: u256, b: u256) {
    let (is_ge) = uint256_le(b, a);
    assert is_ge = TRUE;
    return ();
}
