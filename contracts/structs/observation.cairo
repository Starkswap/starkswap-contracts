from starkware.cairo.common.uint256 import Uint256

struct Observation:
    member block_timestamp: felt

    // @audit values below cannot be trusted, see comments on `_update()` func in StarkswapV1Pair.cairo
    // @audit-info token_reserve * block_timestamp
    // @audit-info (maybe it should've been time_elapsed but because of problem in `_update()` func it's really block_timestamp)
    member cumulative_base_reserve: Uint256
    member cumulative_quote_reserve: Uint256
end
