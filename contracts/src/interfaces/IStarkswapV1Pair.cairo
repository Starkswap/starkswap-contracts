use starkswap_contracts::structs::observation::Observation;
use starknet::ClassHash;
use starknet::ContractAddress;

#[abi]
trait IStarkswapV1Pair {
    // ######### ERC20 functions ##########

    fn name() -> felt252;
    fn symbol() -> felt252;
    fn decimals() -> u8;
    fn total_supply() -> u256;
    fn balance_of(account: ContractAddress) -> u256;
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    fn approve(spender: ContractAddress, amount: u256) -> bool;
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    // ######### END ERC20 functions ##########

    fn MINIMUM_LIQUIDITY() -> u256;
    fn factory() -> ContractAddress;
    fn base_token() -> ContractAddress;
    fn quote_token() -> ContractAddress;
    fn curve() -> (ClassHash, felt252);
    fn get_reserves() -> (u256, u256, felt252);
    fn get_observations(num_observations: felt252) -> Array<Observation>;
    fn last_observations() -> Observation;
    fn k_last() -> u256;
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
