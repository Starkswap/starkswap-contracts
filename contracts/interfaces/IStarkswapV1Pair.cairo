#[abi]
trait IStarkswapV1Pair {
    // ######### ERC20 functions ##########

    fn  name() -> felt;

    fn  symbol() -> felt;

    fn  decimals() -> felt;

    fn  totalSupply() -> u256;

    fn  balanceOf(account: felt) -> u256;

    fn  allowance(owner: felt, spender: felt) -> u256;

    fn  approve(spender: felt, amount: u256) -> felt;

    fn  transfer(recipient: felt, amount: u256) -> felt;

    fn  transferFrom(sender: felt, recipient: felt, amount: u256) -> felt;

    // ######### END ERC20 functions ##########

    fn  MINIMUM_LIQUIDITY() -> u256;

    fn  factory() -> felt;

    fn  baseToken() -> felt;

    fn  quoteToken() -> felt;

    fn  curve() -> (curve_class_hash: felt, curve_name: felt);

    fn  getReserves() -> (
        base_token_reserve: u256, quote_token_reserve: u256, block_timestamp_last: felt
    );

    fn  getObservations(num_observations: felt) -> (
        observations_len: felt, observations: Observation*
    );

    fn  lastObservations() -> Observation;

    fn  kLast() -> u256;

    fn  mint(to: felt) -> u256;

    fn  burn(to: felt) -> (base_token_amount: u256, quote_token_amount: u256);

    fn  swap(
        base_out: u256, quote_out: u256, to: felt, calldata_len: felt, calldata: felt*
    );

    fn  skim(to: felt);

    fn  sync();
}
