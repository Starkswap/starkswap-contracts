use starkswap_contracts::structs::observation::Observation;
use starknet::ClassHash;
use starknet::ContractAddress;

#[abi]
trait IStarkswapV1Pair {
    // ######### ERC20 functions ##########

    fn name() -> felt252;
    fn symbol() -> felt252;
    fn decimals() -> felt252;
    fn totalSupply() -> u256;
    fn balanceOf(account: felt252) -> u256;
    fn allowance(owner: felt252, spender: felt252) -> u256;
    fn approve(spender: felt252, amount: u256) -> felt252;
    fn transfer(recipient: felt252, amount: u256) -> felt252;
    fn transferFrom(sender: felt252, recipient: felt252, amount: u256) -> felt252;
    // ######### END ERC20 functions ##########

    fn MINIMUM_LIQUIDITY() -> u256;
    fn factory() -> ContractAddress;
    fn baseToken() -> ContractAddress;
    fn quoteToken() -> ContractAddress;
    fn curve() -> (ClassHash, felt252);
    fn getReserves() -> (u256, u256, felt252);
    fn getObservations(num_observations: felt252) -> Array<Observation>;
    fn lastObservations() -> Observation;
    fn kLast() -> u256;
    fn mint(to: ContractAddress) -> u256;
    fn burn(to: ContractAddress) -> (u256, u256);
    fn swap(
        base_out: u256,
        quote_out: u256,
        to: ContractAddress,
        calldata_len: felt252,
        calldata: Array<felt252>
    );
    fn skim(to: felt252);
    fn sync();
}
