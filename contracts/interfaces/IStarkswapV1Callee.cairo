#[abi]
trait IStarkswapV1Callee {
    fn starkswapV1Call(
        address: felt,
        base_amount: u256,
        quote_amount: u256,
        calldata_len: felt,
        calldata: felt*,
    );
}
