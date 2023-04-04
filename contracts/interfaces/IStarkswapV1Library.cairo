%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStarkswapV1Library {

    func sortTokens(
        token_a_address: felt,
        token_b_address: felt
        ) -> (base_address: felt, quote_address: felt) {
    }

    func pairFor(
        factory_address: felt,
        pair_class_hash: felt,
        token_a_address: felt,
        token_b_address: felt,
        curve: felt
        ) -> (pair_address: felt) {
    }

    func getReserves(
        factory_address: felt,
        pair_class_hash: felt,
        token_a_address: felt,
        token_b_address: felt,
        curve: felt) -> (base_reserve: Uint256, quote_reserve: Uint256) {
    }

    func quote(
        amount_a: Uint256,
        reserve_a: Uint256,
        reserve_b: Uint256,
        curve: felt
        ) -> (amount_b: Uint256) {
    }

    func getAmountOut(
        amount_out: Uint256,
        reserve_in: Uint256,
        reserve_out: Uint256,
        curve: felt
        ) -> (amount_out: Uint256) {
    }

    func getAmountIn(
        amount_out: Uint256,
        reserve_in: Uint256,
        reserve_out: Uint256,
        curve: felt
        ) -> (amount_in: Uint256) {
    }

    func getAmountsOut(
        factory_address: felt,
        pair_class_hash: felt,
        amount_in: Uint256,
        path_len: felt,
        path: felt*,
        curves_len: felt,
        curves: felt*
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func getAmountsIn(
        factory_address: felt,
        pair_class_hash: felt,
        amount_in: Uint256,
        path_len: felt,
        path: felt*,
        curves_len: felt,
        curves: felt*
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }
}