from starkware.cairo.common.uint256 import Uint256

struct Balance {
    pair_address: felt,
    pair_balance: Uint256,
    base_balance: Uint256,
    quote_balance: Uint256,
    total_supply: Uint256,
    base_reserve: Uint256,
    quote_reserve: Uint256,
}