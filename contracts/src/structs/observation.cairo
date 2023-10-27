#[derive(Copy, Drop, Serde, storage_access::StorageAccess)]
struct Observation {
    block_timestamp: u64,
    cumulative_base_reserve: u256,
    cumulative_quote_reserve: u256,
}
