#[derive(Serde, Copy, Drop)]
struct Route {
    input: felt252,
    output: felt252,
    curve: felt252,
}
