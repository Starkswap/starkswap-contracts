use starknet::ContractAddress;

#[abi]
trait IStarkswapV1Callee {
    fn starkswapV1Call(
        address: ContractAddress, base_amount: u256, quote_amount: u256, calldata: Array<felt252>
    );
}
