use integer::u256_from_felt252;

fn assert_uint256_zero(val: u256) implicits(RangeCheck) {
    assert(val == u256_from_felt252(0), 'val is not zero');
}

fn assert_uint256_gt(a: u256, b: u256) implicits(RangeCheck) {
    assert(a > b, 'a is not > b');
}

fn assert_uint256_ge(a: u256, b: u256) implicits(RangeCheck) {
    assert(a >= b, 'a is not >= b');
}
