#[abi]
namespace IStarkswapV1Library {

    fn sortTokens(
        token_a_address: felt,
        token_b_address: felt
        ) -> (base_address: felt, quote_address: felt);

    fn pairFor(
        factory_address: felt,
        pair_class_hash: felt,
        token_a_address: felt,
        token_b_address: felt,
        curve: felt
        ) -> felt;

    fn getReserves(
        factory_address: felt,
        pair_class_hash: felt,
        token_a_address: felt,
        token_b_address: felt,
        curve: felt) -> (base_reserve: u256, quote_reserve: u256);

    fn quote(
        amount_a: u256,
        reserve_a: u256,
        reserve_b: u256,
        curve: felt
        ) -> u256;

    fn getAmountOut(
        amount_out: u256,
        reserve_in: u256,
        reserve_out: u256,
        curve: felt
        ) -> u256;

    fn getAmountIn(
        amount_out: u256,
        reserve_in: u256,
        reserve_out: u256,
        curve: felt
        ) -> u256;

    fn getAmountsOut(
        factory_address: felt,
        pair_class_hash: felt,
        amount_in: u256,
        path_len: felt,
        path: felt*,
        curves_len: felt,
        curves: felt*
        ) -> (amounts_len: felt, amounts: u256*);

    fn getAmountsIn(
        factory_address: felt,
        pair_class_hash: felt,
        amount_in: u256,
        path_len: felt,
        path: felt*,
        curves_len: felt,
        curves: felt*
        ) -> (amounts_len: felt, amounts: u256*);
}