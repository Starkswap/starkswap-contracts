use integer::u256_from_felt252;

const DECIMAL_18_NORMALISER: felt252 = 1000000000000000000;

fn make_18_dec(value: u256, decimals: felt252) -> u256 implicits(RangeCheck) {
    if (decimals == 18) {
        return value;
    } else {
        //TODO: find out how pow works
        let decimal_scaler = u256_from_felt252(10); //u256_from_felt252(10).pow(decimals);
        let r0 = value * u256_from_felt252(DECIMAL_18_NORMALISER);
        let normalised_value = r0 / decimal_scaler;

        return normalised_value;
    }
}

fn unmake_18_dec(value: u256, decimals: felt252) -> u256 implicits(RangeCheck) {
    if (decimals == 18) {
        return value;
    } else {
        //TODO: find out how pow works
        let decimal_scaler = u256_from_felt252(10); //u256_from_felt252(10).pow(decimals);
        let r0 = value * decimal_scaler;
        let normalised_value = r0 / u256_from_felt252(DECIMAL_18_NORMALISER);

        return normalised_value;
    }
}
