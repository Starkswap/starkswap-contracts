#[abi]
trait IStarkswapV1Factory {
    fn feeTo() -> felt;

    fn pairClassHash() -> felt;

    fn feeToSetter() -> felt;

        fn getCurve(curve_class_hash: felt) -> felt;

        fn getPair(token_a_address: felt, token_b_address: felt, curve: felt) -> felt;

        fn allPairs(index: felt) -> felt;

        fn allPairsLength() -> felt;

        fn getAllPairs() -> (pairs_len: felt, pairs: Pair*);

        fn createPair(token_a_address: felt, token_b_address: felt, curve: felt) -> felt;

        fn setFeeTo(address: felt) -> felt;

        fn setFeeToSetter(address: felt) -> felt;

        fn setPairClassHash(pair_class_hash: felt) -> felt;

        fn addCurve(curve_class_hash: felt) -> felt;

        fn getBalances(account: felt) -> (balances_len: felt, balances: Balance*);
}
