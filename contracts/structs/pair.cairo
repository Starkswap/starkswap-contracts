#[derive(Copy, Drop)]
struct Pair {
    pair: Token,
    base: Token,
    quote: Token,
    curve: felt,
}
