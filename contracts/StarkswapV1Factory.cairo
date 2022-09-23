%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.math import (
    assert_not_zero, assert_nn_le, assert_nn, assert_not_equal
)
from starkware.starknet.common.syscalls import (
    get_caller_address, deploy)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from contracts.utils.sort import _sort_tokens

from contracts.structs.pair import Pair
from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from contracts.interfaces.IStarkswapV1Pair import IStarkswapV1Pair

#####################################################################
# Storage
#####################################################################

// @audit-info mapping(base_addr, quote_addr, curve) -> pair_addr
@storage_var
func sv_pair(base_address: felt, quote_address: felt, curve: felt) -> (pair_address: felt):
end

// @audit-info mapping(curve_class_hash) -> bool
// @audit-info whether given curve was created
@storage_var
func sv_curve_class_hash(curve_class_hash: felt) -> (exists: felt):
end

@storage_var
func sv_fee_to_setter() -> (fee_too_setter_address: felt):
end

@storage_var
func sv_fee_to() -> (fee_too_address: felt):
end

// @audit-info mapping(index) -> pair_addr
@storage_var
func sv_pair_by_index(index: felt) -> (pair_address: felt):
end

@storage_var
func sv_pairs_count() -> (all_pairs_length: felt):
end

// @audit-info pair contract implementation hash
@storage_var
func sv_pair_class_hash() -> (pair_class_hash: felt):
end

#####################################################################
# Constructor
#####################################################################

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    setter: felt,
    pair_class_hash: felt,
    ):

    // @audit-info set fee_to setter
    assert_not_zero(setter)
    sv_fee_to_setter.write(setter)

    // @audit-info set pair contract implementation (`pair_class_hash`)
    assert_not_zero(pair_class_hash)
    sv_pair_class_hash.write(pair_class_hash)

    return ()

end

#####################################################################
# View functions
#####################################################################

// @audit-info get `pair_class_hash`
@view
func pairClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (pair_class_hash: felt):
    return sv_pair_class_hash.read()
end

// @audit-info return whether curve with given class hash was created (by `addCurve()`)
@view
func getCurve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(curve_class_hash: felt) -> (exists: felt):
    return sv_curve_class_hash.read(curve_class_hash)
end

// @audit-info get fee recipient
@view
func feeTo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt):
    let (address: felt) = sv_fee_to.read()
    return (address)
end

// @audit-info get address capable of setting fee recipient
@view
func feeToSetter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt):
    let (address: felt) = sv_fee_to_setter.read()
    return (address)
end

// @audit-info get pair contract address (given token addresses and curve)
// @audit is it the curve class hash that's being given?
@view
func getPair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_a_address: felt,
    token_b_address: felt,
    curve: felt
    ) -> (pair_address: felt):

    let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address)
    let (pair_address: felt) = sv_pair.read(base_address, quote_address, curve)

    return (pair_address)

end

// @audit-info get pair address at index
@view
func allPairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt
    ) -> (pair_address: felt):

    let (all_pairs_counter: felt) = sv_pairs_count.read()

    # Only allow 0 <= index < length of all pairs
    assert_nn_le(index, all_pairs_counter)

    let (pair_address: felt) = sv_pair_by_index.read(index)

    return (pair_address)

end

// @audit-info 
@view
func allPairsLength{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (all_pairs_length: felt):

    let (all_pairs_counter: felt) = sv_pairs_count.read()
    return (all_pairs_counter)

end

// @audit-info recursive func gets pairs into Pair array
func _get_pairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        pairs_len: felt, pairs: Pair*):

    // @audit dangerous equality, check what's possible to input
    if pairs_len == -1:
        return ()
    end

    // @audit-info get pair info at `pairs_len` index into Pair struct
    let (pair_address: felt) = sv_pair_by_index.read(pairs_len)
    let (base_address: felt) = IStarkswapV1Pair.baseToken(contract_address=pair_address)
    let (quote_address: felt) = IStarkswapV1Pair.quoteToken(contract_address=pair_address)
    let (curve: felt, _) = IStarkswapV1Pair.curve(contract_address=pair_address)
    let pair: Pair = Pair(base_address, quote_address, pair_address, curve)

    // @audit-info put Pair struct into array
    assert pairs[pairs_len] = pair

    // @audit-info recursive call
    return _get_pairs(pairs_len - 1, pairs)

end

// @audit-info alloc new segment and get all Pair structs in it
@view
func getAllPairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    pairs_len: felt, pairs: Pair*):

    alloc_locals

    let (local pairs_len: felt) = sv_pairs_count.read()
    let (local pairs : Pair*) = alloc()

    _get_pairs(pairs_len - 1, pairs)

    return (pairs_len, pairs)

end

#####################################################################
# External functions
#####################################################################

// @audit-info set fee recipient
@external
func setFeeTo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) -> (address: felt):

    // @audit-info only if caller is fee_setter
    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    // @audit-info set fee recipient
    sv_fee_to.write(address)
    return (address)

end

// @audit-info set fee recipient setter
@external
func setFeeToSetter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) -> (address: felt):

    // @audit-info only if caller is fee_setter
    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    // @audit-info set fee recipient setter
    sv_fee_to_setter.write(address)
    return (address)

end

// @audit-info set pair class implementation
@external
func setPairClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_class_hash: felt
    ) -> (pair_class_hash: felt):

    // @audit-info only if caller is fee_setter
    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    sv_pair_class_hash.write(pair_class_hash)
    return (pair_class_hash)

end

// @audit-info add curve class hash to `sv_curve_class_hash` mapping
// @audit can you add curve hash without adding actual curve? what are the consequences?
@external
func addCurve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    curve_class_hash: felt
    ) -> (exists: felt):

    // @audit-info only if caller is fee_setter
    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    sv_curve_class_hash.write(curve_class_hash, TRUE)
    return (curve_class_hash)

end

// @audit-info deploy pair contract and update this contract's fields
@external
func createPair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_a_address: felt,
    token_b_address: felt,
    curve: felt
    ) -> (pair_address: felt):

    alloc_locals

    // @audit-info assert curve exists in `sv_curve_class_hash`
    with_attr error_message("StarkswapV1Factory: INVALID_CURVE"):
        let (curve_class_hash: felt) = sv_curve_class_hash.read(curve)
        assert curve_class_hash = TRUE
    end

    // @audit-info assert token_a != token_b
    with_attr error_message("StarkswapV1Factory: IDENTICAL_ADDRESSES"):
        assert_not_equal(token_a_address, token_b_address)
    end

    // @audit-info sort tokens
    let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address)

    // @audit-info base_token != address(0)
    with_attr error_message("StarkswapV1Factory: ZERO_ADDRESS"):
        assert_not_zero(base_address)
    end

    // @audit-info assert pair doesn't already exist (using `sv_pair` mapping)
    with_attr error_message("StarkswapV1Factory: PAIR_EXISTS"):
        let (existing_pair: felt) = sv_pair.read(base_address, quote_address, curve)
        assert existing_pair = FALSE
    end

    // @audit-info deploy pair
    let (pair_address: felt) = _deploy_starkswap_v1_pair(base_address, quote_address, curve)

    // @audit-info add pair to pair mapping by params, pair mapping by index, and increment pairs_count
    sv_pair.write(base_address, quote_address, curve, pair_address)
    let (length: felt) = sv_pairs_count.read()
    assert_nn(length + 1)
    sv_pair_by_index.write(length, pair_address)
    sv_pairs_count.write(length + 1)

    return (pair_address)

end

// @audit-info deploy pair (contract implementation hash is `sv_pair_class_hash`)
func _deploy_starkswap_v1_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_address: felt,
    quote_address: felt,
    curve: felt
    ) -> (contract_address):

    // @audit-info deploy pair
    // @audit understand all the params here
    let (pair_class_hash) = sv_pair_class_hash.read()
    let (contract_address) = deploy(
        class_hash=pair_class_hash,
        contract_address_salt=0,
        constructor_calldata_size=3,
        constructor_calldata=cast(new (base_address, quote_address, curve), felt*),
        deploy_from_zero=FALSE,
    )
    return (contract_address)

end
