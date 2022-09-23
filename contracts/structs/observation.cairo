from starkware.cairo.common.uint256 import Uint256

struct Observation:
    member block_timestamp: felt
    member cumulative_base_reserve: Uint256
    member cumulative_quote_reserve: Uint256
end
