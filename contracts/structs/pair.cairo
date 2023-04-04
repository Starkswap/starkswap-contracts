from contracts.structs.token import Token

struct Pair {
    pair: Token,
    base: Token,
    quote: Token,
    curve: felt,
}
