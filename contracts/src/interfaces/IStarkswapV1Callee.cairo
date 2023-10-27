use starknet::ContractAddress;

#[starknet::interface]
trait IStarkswapV1Callee<TContractState> {
    fn starkswapV1Call(
        self: @TContractState, address: ContractAddress, base_amount: u256, quote_amount: u256, calldata: Array<felt252>
    );
}
