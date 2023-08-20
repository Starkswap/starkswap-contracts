use array::ArrayTrait;
use array::Span;
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use traits::Into;
use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::class_hash::ClassHashZeroable;
use starknet::Felt252TryIntoContractAddress;
use starknet::contract_address::ContractAddressIntoFelt252;
use dict::Felt252DictTrait;

use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1FactoryDispatcher;
use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1FactoryDispatcherTrait;

use starknet::contract_address_const;
use snforge_std::{declare, PreparedContract, deploy, PrintTrait};

fn deploy_contract(ref class_hashes: Felt252Dict<felt252>, name: felt252, args: @Array<felt252>) -> ContractAddress {
    let mut class_hash: ClassHash = class_hashes.get(name).try_into().unwrap();
    if class_hash == ClassHashZeroable::zero() {
        'declaring contract'.print();
        class_hash = declare(name);
        class_hashes.insert(name, class_hash.into());
    } else {
        'using cached ClassHash'.print()
    }
    name.print();

    let prepared = PreparedContract {
        class_hash: class_hash, constructor_calldata: args
    };

    deploy(prepared).unwrap()
}

fn deploy_token(ref class_hashes: Felt252Dict<felt252>, name: felt252, symbol: felt252, initial_supply: u256, recipient: ContractAddress) -> ContractAddress {
    let mut args: Array<felt252> = ArrayTrait::new();
    args.append(name);
    args.append(symbol);
    args.append(initial_supply.low.into());
    args.append(initial_supply.high.into());
    args.append(recipient.into());

    deploy_contract(ref class_hashes, 'ERC20', @args)
}

fn token_fixutre(ref class_hashes: Felt252Dict<felt252>, owner: ContractAddress) -> (ContractAddress, ContractAddress) {
    let INITIAL_SUPPLY: u256 = u256{ low: 10000, high: 0 };
    let token_a = deploy_token(ref class_hashes, 'Token A', 'TKA', INITIAL_SUPPLY, owner);
    let token_b = deploy_token(ref class_hashes, 'Token B', 'TKB', INITIAL_SUPPLY, owner);

    (token_a, token_b)
}

fn factory_fixture(ref class_hashes: Felt252Dict<felt252>, owner: ContractAddress) -> ContractAddress {
    let stable_curve_hash = declare('StarkswapV1Stable');
    let volatile_curve_hash = declare('StarkswapV1Volatile');
    let pair_class_hash = declare('StarkswapV1Pair');

    let mut args: Array<felt252> = ArrayTrait::new();
    args.append(owner.into());
    args.append(pair_class_hash.into());
    let factory_address = deploy_contract(ref class_hashes, 'StarkswapV1Factory', @args);

    let dispatcher = IStarkswapV1FactoryDispatcher { contract_address: factory_address };
    dispatcher.add_curve_class_hash( curve_class_hash: volatile_curve_hash );
    dispatcher.add_curve_class_hash( curve_class_hash: stable_curve_hash );


    factory_address
}


//fn router_fixture(ref class_hashes: Felt252Dict<ClassHash>, factory_class_hash: ClassHash, pair_class_hash: PairClassHash, owner: ContractAddress) -> ContractAddress {
    //let mut args: Array<felt252> = ArrayTrait::new();
    //args.append(factory_class_hash.into());
    //args.append(pair_class_hash.into());

    //deploy_contract(ref class_hashes, 'StarkswapV1Router', @args)
//}


#[test]
fn test_increase_balance() {
    let OWNER = contract_address_const::<42>();

    let mut class_hashes: Felt252Dict<felt252> = Default::default();
    let (token_a_address, token_b_address) = token_fixutre(ref class_hashes, OWNER);
    let factory_address = factory_fixture(ref class_hashes, OWNER);

    //let safe_dispatcher = IERC20Dispatcher { contract_address };

    //let x = contract_address_const::<0>();
    //let balance_before = safe_dispatcher.balance_of(x);
    //assert(balance_before == 0, 'Invalid balance');
}

