use starkswap_contracts::structs::token::Token;
use starknet::ClassHash;

#[derive(Serde, Copy, Drop)]
struct Pair {
    pair: Token,
    base: Token,
    quote: Token,
    curve: ClassHash,
}
