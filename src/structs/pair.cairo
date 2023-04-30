use starkswap_contracts::structs::token::Token;

#[derive(Serde, Copy, Drop)]
struct Pair {
    pair: Token,
    base: Token,
    quote: Token,
    curve: felt252,
}
