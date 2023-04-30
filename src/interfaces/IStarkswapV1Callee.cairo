#[abi]
trait IStarkswapV1Callee {
    fn starkswapV1Call(
        address: felt252,
        base_amount: u256,
        quote_amount: u256,
        calldata_len: felt252,
        calldata: Array<felt252>,
    );
}
