#[derive(Copy, Drop)]
struct Balance {
    pair_address: felt,
    pair_balance: u256,
    base_balance: u256,
    quote_balance: u256,
    total_supply: u256,
    base_reserve: u256,
    quote_reserve: u256,
}