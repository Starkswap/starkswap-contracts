use starkswap_contracts::structs::route::Route;

#[abi]
trait IStarkswapV1Router {
    fn factory() -> felt252;

    fn addLiquidity(
        token_a_address: felt252,
        token_b_address: felt252,
        curve: felt252,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: felt252,
        deadline: felt252,
    ) -> (u256, u256, u256);

    fn removeLiquidity(
        token_a_address: felt252,
        token_b_address: felt252,
        curve: felt252,
        liquidity: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: felt252,
        deadline: felt252,
    ) -> (u256, u256);

    fn swapExactTokensForTokens(
        amount_in: u256,
        amount_out_min: u256,
        routes_len: felt252,
        routes: Array<Route>,
        to: felt252,
        deadline: felt252,
    ) -> (felt252, Array<u256>);

    fn swapTokensForExactTokens(
        amount_out: u256,
        amount_in_max: u256,
        routes_len: felt252,
        routes: Array<Route>,
        to: felt252,
        deadline: felt252,
    ) -> (felt252, Array<u256>);

    // TODO: implement
    // fn quote(
    // amount_a: u256,
    // reserve_a: u256,
    // reserve_b: u256,
    // curve: felt252
    // ) -> (amount_b: u256):
    // end

    fn getAmountOut(
        amount_in: u256, reserve_in: u256, reserve_out: u256, curve: felt252
    ) -> u256;

    fn getAmountIn(
        amount_out: u256, reserve_in: u256, reserve_out: u256, curve: felt252
    ) -> u256;

    fn getAmountsOut(amount_in: u256, routes_len: felt252, routes: Array<Route>) -> (
        felt252, Array<u256>
    );

    fn getAmountsIn(amount_out: u256, routes_len: felt252, routes: Array<Route>) -> (
        felt252, Array<u256>
    );
}
