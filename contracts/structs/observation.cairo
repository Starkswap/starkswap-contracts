from starkware.cairo.common.uint256 import Uint256

struct Observation {
    block_timestamp: felt,
    cumulative_base_reserve: Uint256,
    cumulative_quote_reserve: Uint256,
}
