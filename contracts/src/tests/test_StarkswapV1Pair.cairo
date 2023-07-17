use starkswap_contracts::StarkswapV1Pair::StarkswapV1Pair;
use openzeppelin::token::erc20::ERC20;
use starknet::contract_address_const;
use starknet::ContractAddress;


#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let INITIAL_SUPPLY: u256 = u256 { low: 10000000000000000000000_u128, high: 0_u128 };
    let owner: ContractAddress = contract_address_const::<1>();
    let base_pair = ERC20::constructor('Token A', 'TKA', INITIAL_SUPPLY, owner);
    let quote_pair = ERC20::constructor('Token B', 'TKB', INITIAL_SUPPLY, owner);
//let pair = StarkswapV1Pair::constructor(
//base_pair::address(),
//quote_pair::address()
//);
}
