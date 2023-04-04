%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStarkswapV1Callee {
    func starkswapV1Call(
        address: felt,
        base_amount: Uint256,
        quote_amount: Uint256,
        calldata_len: felt,
        calldata: felt*,
    ) {
    }
}
