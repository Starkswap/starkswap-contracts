%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStarkswapV1Curve {
    func name() -> (name: felt) {
    }

    func get_amount_out(amount_in: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> (amount_out: Uint256) {
    }

    func get_amount_in(amount_out: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> (amount_in: Uint256) {
    }

    func get_k(reserve_a: Uint256, reserve_b: Uint256) -> (k: Uint256) {
    }
}
