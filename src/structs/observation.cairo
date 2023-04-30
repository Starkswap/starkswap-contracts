#[derive(Serde, Copy, Drop)]
struct Observation {
    block_timestamp: felt252,
    cumulative_base_reserve: u256,
    cumulative_quote_reserve: u256,
}
