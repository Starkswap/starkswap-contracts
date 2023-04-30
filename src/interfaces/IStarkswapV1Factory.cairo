use starkswap_contracts::structs::balance::Balance;
use starkswap_contracts::structs::pair::Pair;

#[abi]
trait IStarkswapV1Factory {
    fn feeTo() -> felt252;

    fn pairClassHash() -> felt252;

    fn feeToSetter() -> felt252;

        fn getCurve(curve_class_hash: felt252) -> felt252;

        fn getPair(token_a_address: felt252, token_b_address: felt252, curve: felt252) -> felt252;

        fn allPairs(index: felt252) -> felt252;

        fn allPairsLength() -> felt252;

        fn getAllPairs() -> (felt252, Array<Pair>);

        fn createPair(token_a_address: felt252, token_b_address: felt252, curve: felt252) -> felt252;

        fn setFeeTo(address: felt252) -> felt252;

        fn setFeeToSetter(address: felt252) -> felt252;

        fn setPairClassHash(pair_class_hash: felt252) -> felt252;

        fn addCurve(curve_class_hash: felt252) -> felt252;

        fn getBalances(account: felt252) -> (felt252, Array<Balance>);
}
