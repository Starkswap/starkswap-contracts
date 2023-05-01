use starkswap_contracts::structs::observation::Observation;

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
    fn factory() -> felt252;
    fn baseToken() -> felt252;
    fn quoteToken() -> felt252;
    fn curve() -> (felt252, felt252);
    fn getReserves() -> (u256, u256, felt252);
    fn getObservations(num_observations: felt252) -> (felt252, Array<Observation>);
    fn lastObservations() -> Observation;
    fn kLast() -> u256;
    fn mint(to: felt252) -> u256;
    fn burn(to: felt252) -> (u256, u256);
    fn swap(
        base_out: u256,
        quote_out: u256,
        to: felt252,
        calldata_len: felt252,
        calldata: Array<felt252>
    );
    fn skim(to: felt252);
    fn sync();
}
