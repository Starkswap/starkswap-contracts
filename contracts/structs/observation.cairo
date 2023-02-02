#[derive(Copy, Drop)]
struct Observation {
    block_timestamp: felt,
    cumulative_base_reserve: u256,
    cumulative_quote_reserve: u256,
}
