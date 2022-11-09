%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.math import assert_not_zero, assert_nn_le, assert_nn, assert_not_equal
from starkware.starknet.common.syscalls import get_caller_address, deploy
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from contracts.utils.sort import _sort_tokens

from contracts.structs.pair import Pair
from contracts.structs.balance import Balance
from contracts.structs.token import Token
from openzeppelin.token.erc20.IERC20 import IERC20
from contracts.interfaces.IStarkswapV1Pair import IStarkswapV1Pair

//####################################################################
// Storage
//####################################################################

@storage_var
func sv_pair(base_address: felt, quote_address: felt, curve: felt) -> (pair_address: felt) {
}

@storage_var
func sv_curve_class_hash(curve_class_hash: felt) -> (exists: felt) {
}

@storage_var
func sv_fee_to_setter() -> (fee_too_setter_address: felt) {
}

@storage_var
func sv_fee_to() -> (fee_too_address: felt) {
}

@storage_var
func sv_pair_by_index(index: felt) -> (pair_address: felt) {
}

@storage_var
func sv_pairs_count() -> (all_pairs_length: felt) {
}

@storage_var
func sv_pair_class_hash() -> (pair_class_hash: felt) {
}

//####################################################################
// Constructor
//####################################################################

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    setter: felt, pair_class_hash: felt
) {
    assert_not_zero(setter);
    sv_fee_to_setter.write(setter);

    assert_not_zero(pair_class_hash);
    sv_pair_class_hash.write(pair_class_hash);

    return ();
}

//####################################################################
// View functions
//####################################################################

@view
func pairClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    pair_class_hash: felt
) {
    return sv_pair_class_hash.read();
}

@view
func getCurve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    curve_class_hash: felt
) -> (exists: felt) {
    return sv_curve_class_hash.read(curve_class_hash);
}

@view
func feeTo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt) {
    let (address: felt) = sv_fee_to.read();
    return (address,);
}

@view
func feeToSetter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    let (address: felt) = sv_fee_to_setter.read();
    return (address,);
}

@view
func getPair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_a_address: felt, token_b_address: felt, curve: felt
) -> (pair_address: felt) {
    let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address);
    let (pair_address: felt) = sv_pair.read(base_address, quote_address, curve);

    return (pair_address,);
}

@view
func allPairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(index: felt) -> (
    pair_address: felt
) {
    let (all_pairs_counter: felt) = sv_pairs_count.read();

    assert_nn_le(index, all_pairs_counter);

    let (pair_address: felt) = sv_pair_by_index.read(index);

    return (pair_address,);
}

@view
func allPairsLength{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    all_pairs_length: felt
) {
    let (all_pairs_counter: felt) = sv_pairs_count.read();
    return (all_pairs_counter,);
}

func _get_pairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pairs_len: felt, pairs: Pair*
) {
    if (pairs_len == -1) {
        return ();
    }

    let (pair_address: felt) = sv_pair_by_index.read(pairs_len);
    let (base_address: felt) = IStarkswapV1Pair.baseToken(contract_address=pair_address);

    let (pair_name: felt) = IStarkswapV1Pair.name(contract_address=base_address);
    let (pair_symbol: felt) = IStarkswapV1Pair.symbol(contract_address=base_address);
    let (pair_decimals: felt) = IStarkswapV1Pair.decimals(contract_address=base_address);
    let pair_token: Token = Token(pair_address, pair_name, pair_symbol, pair_decimals);

    let (base_name: felt) = IERC20.name(contract_address=base_address);
    let (base_symbol: felt) = IERC20.symbol(contract_address=base_address);
    let (base_decimals: felt) = IERC20.decimals(contract_address=base_address);
    let base_token: Token = Token(base_address, base_name, base_symbol, base_decimals);

    let (quote_address: felt) = IStarkswapV1Pair.quoteToken(contract_address=pair_address);
    let (quote_name: felt) = IERC20.name(contract_address=quote_address);
    let (quote_symbol: felt) = IERC20.symbol(contract_address=quote_address);
    let (quote_decimals: felt) = IERC20.decimals(contract_address=quote_address);
    let quote_token: Token = Token(quote_address, quote_name, quote_symbol, quote_decimals);

    let (curve: felt, _) = IStarkswapV1Pair.curve(contract_address=pair_address);
    let pair: Pair = Pair(pair_token, base_token, quote_token, curve);

    assert pairs[pairs_len] = pair;

    return _get_pairs(pairs_len - 1, pairs);
}

@view
func getAllPairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    pairs_len: felt, pairs: Pair*
) {
    alloc_locals;

    let (local pairs_len: felt) = sv_pairs_count.read();
    let (local pairs: Pair*) = alloc();

    _get_pairs(pairs_len - 1, pairs);

    return (pairs_len, pairs);
}

func _get_balances{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, balances_len: felt, balances: Balance*
) {
    if (balances_len == -1) {
        return ();
    }

    let (pair_address: felt) = sv_pair_by_index.read(balances_len);
    let (pair_balance: Uint256) = IStarkswapV1Pair.balanceOf(
        contract_address=pair_address, account=account
    );
    let (base_address: felt) = IStarkswapV1Pair.baseToken(contract_address=pair_address);
    let (base_balance: Uint256) = IERC20.balanceOf(contract_address=base_address, account=account);
    let (quote_address: felt) = IStarkswapV1Pair.quoteToken(contract_address=pair_address);
    let (quote_balance: Uint256) = IERC20.balanceOf(
        contract_address=quote_address, account=account
    );

    let (total_supply: Uint256) = IStarkswapV1Pair.totalSupply(contract_address=pair_address);
    let (
        base_token_reserve: Uint256, quote_token_reserve: Uint256, _
    ) = IStarkswapV1Pair.getReserves(contract_address=pair_address);

    let balance: Balance = Balance(
        pair_address,
        pair_balance,
        base_balance,
        quote_balance,
        total_supply,
        base_token_reserve,
        quote_token_reserve,
    );

    assert balances[balances_len] = balance;

    return _get_balances(account, balances_len - 1, balances);
}

@view
func getBalances{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt
) -> (balances_len: felt, balances: Balance*) {
    alloc_locals;
    assert_not_zero(account);

    let (local balances_len: felt) = sv_pairs_count.read();
    let (local balances: Balance*) = alloc();

    _get_balances(account, balances_len - 1, balances);

    return (balances_len, balances);
}

//####################################################################
// External functions
//####################################################################

@external
func setFeeTo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) -> (
    address: felt
) {
    with_attr error_message("StarkswapV1Factory: FORBIDDEN") {
        let (caller_address: felt) = get_caller_address();
        let (setter: felt) = sv_fee_to_setter.read();
        assert caller_address = setter;
    }

    sv_fee_to.write(address);
    return (address,);
}

@external
func setFeeToSetter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (address: felt) {
    with_attr error_message("StarkswapV1Factory: FORBIDDEN") {
        let (caller_address: felt) = get_caller_address();
        let (setter: felt) = sv_fee_to_setter.read();
        assert caller_address = setter;
    }

    sv_fee_to_setter.write(address);
    return (address,);
}

@external
func setPairClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_class_hash: felt
) -> (pair_class_hash: felt) {
    with_attr error_message("StarkswapV1Factory: FORBIDDEN") {
        let (caller_address: felt) = get_caller_address();
        let (setter: felt) = sv_fee_to_setter.read();
        assert caller_address = setter;
    }

    sv_pair_class_hash.write(pair_class_hash);
    return (pair_class_hash,);
}

@external
func addCurve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    curve_class_hash: felt
) -> (exists: felt) {
    with_attr error_message("StarkswapV1Factory: FORBIDDEN") {
        let (caller_address: felt) = get_caller_address();
        let (setter: felt) = sv_fee_to_setter.read();
        assert caller_address = setter;
    }

    sv_curve_class_hash.write(curve_class_hash, TRUE);
    return (curve_class_hash,);
}

@external
func createPair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_a_address: felt, token_b_address: felt, curve: felt
) -> (pair_address: felt) {
    alloc_locals;

    with_attr error_message("StarkswapV1Factory: INVALID_CURVE") {
        let (curve_class_hash: felt) = sv_curve_class_hash.read(curve);
        assert curve_class_hash = TRUE;
    }

    with_attr error_message("StarkswapV1Factory: IDENTICAL_ADDRESSES") {
        assert_not_equal(token_a_address, token_b_address);
    }

    let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address);

    with_attr error_message("StarkswapV1Factory: ZERO_ADDRESS") {
        assert_not_zero(base_address);
    }

    with_attr error_message("StarkswapV1Factory: PAIR_EXISTS") {
        let (existing_pair: felt) = sv_pair.read(base_address, quote_address, curve);
        assert existing_pair = FALSE;
    }

    let (pair_address: felt) = _deploy_starkswap_v1_pair(base_address, quote_address, curve);

    sv_pair.write(base_address, quote_address, curve, pair_address);
    let (length: felt) = sv_pairs_count.read();
    assert_nn(length + 1);
    sv_pair_by_index.write(length, pair_address);
    sv_pairs_count.write(length + 1);

    return (pair_address,);
}

func _deploy_starkswap_v1_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_address: felt, quote_address: felt, curve: felt
) -> (contract_address: felt) {
    let (pair_class_hash) = sv_pair_class_hash.read();
    let (contract_address) = deploy(
        class_hash=pair_class_hash,
        contract_address_salt=0,
        constructor_calldata_size=3,
        constructor_calldata=cast(new (base_address, quote_address, curve), felt*),
        deploy_from_zero=FALSE,
    );
    return (contract_address,);
}
