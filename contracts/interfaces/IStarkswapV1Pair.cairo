%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.structs.observation import Observation

@contract_interface
namespace IStarkswapV1Pair {
    // ######### ERC20 functions ##########

    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (totalSupply: Uint256) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    // ######### END ERC20 functions ##########

    func MINIMUM_LIQUIDITY() -> (minimum: Uint256) {
    }

    func factory() -> (address: felt) {
    }

    func baseToken() -> (address: felt) {
    }

    func quoteToken() -> (address: felt) {
    }

    func curve() -> (curve_class_hash: felt, curve_name: felt) {
    }

    func getReserves() -> (
        base_token_reserve: Uint256, quote_token_reserve: Uint256, block_timestamp_last: felt
    ) {
    }

    func getObservations(num_observations: felt) -> (
        observations_len: felt, observations: Observation*
    ) {
    }

    func lastObservations() -> (observation: Observation) {
    }

    func kLast() -> (k_last: Uint256) {
    }

    func mint(to: felt) -> (liquidity: Uint256) {
    }

    func burn(to: felt) -> (base_token_amount: Uint256, quote_token_amount: Uint256) {
    }

    func swap(
        base_out: Uint256, quote_out: Uint256, to: felt, calldata_len: felt, calldata: felt*
    ) {
    }

    func skim(to: felt) {
    }

    func sync() {
    }
}
