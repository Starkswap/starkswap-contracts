#[abi]
trait IStarkswapV1Library {
    fn sortTokens(token_a_address: felt252, token_b_address: felt252) -> (felt252, felt252);
    fn pairFor(
        factory_address: felt252,
        pair_class_hash: felt252,
        token_a_address: felt252,
        token_b_address: felt252,
        curve: felt252
    ) -> felt252;
    fn getReserves(
        factory_address: felt252,
        pair_class_hash: felt252,
        token_a_address: felt252,
        token_b_address: felt252,
        curve: felt252
    ) -> (u256, u256);
    fn quote(amount_a: u256, reserve_a: u256, reserve_b: u256, curve: felt252) -> u256;
    fn getAmountOut(amount_out: u256, reserve_in: u256, reserve_out: u256, curve: felt252) -> u256;
    fn getAmountIn(amount_out: u256, reserve_in: u256, reserve_out: u256, curve: felt252) -> u256;
    fn getAmountsOut(
        factory_address: felt252,
        pair_class_hash: felt252,
        amount_in: u256,
        path_len: felt252,
        path: Array<felt252>,
        curves_len: felt252,
        curves: Array<felt252>
    ) -> (felt252, Array<u256>);
    fn getAmountsIn(
        factory_address: felt252,
        pair_class_hash: felt252,
        amount_in: u256,
        path_len: felt252,
        path: Array<felt252>,
        curves_len: felt252,
        curves: Array<felt252>
    ) -> (felt252, Array<u256>);
}
