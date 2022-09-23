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

@storage_var
func sv_pair(base_address: felt, quote_address: felt, curve: felt) -> (pair_address: felt):
end

@storage_var
func sv_curve_class_hash(curve_class_hash: felt) -> (exists: felt):
end

@storage_var
func sv_fee_to_setter() -> (fee_too_setter_address: felt):
end

@storage_var
func sv_fee_to() -> (fee_too_address: felt):
end

@storage_var
func sv_pair_by_index(index: felt) -> (pair_address: felt):
end

@storage_var
func sv_pairs_count() -> (all_pairs_length: felt):
end

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

    assert_not_zero(setter)
    sv_fee_to_setter.write(setter)

    assert_not_zero(pair_class_hash)
    sv_pair_class_hash.write(pair_class_hash)

    return ()

end

#####################################################################
# View functions
#####################################################################

@view
func pairClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (pair_class_hash: felt):
    return sv_pair_class_hash.read()
end

@view
func getCurve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(curve_class_hash: felt) -> (exists: felt):
    return sv_curve_class_hash.read(curve_class_hash)
end

@view
func feeTo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt):
    let (address: felt) = sv_fee_to.read()
    return (address)
end

@view
func feeToSetter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt):
    let (address: felt) = sv_fee_to_setter.read()
    return (address)
end

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

@view
func allPairsLength{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (all_pairs_length: felt):

    let (all_pairs_counter: felt) = sv_pairs_count.read()
    return (all_pairs_counter)

end

func _get_pairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        pairs_len: felt, pairs: Pair*):

    if pairs_len == -1:
        return ()
    end

    let (pair_address: felt) = sv_pair_by_index.read(pairs_len)
    let (base_address: felt) = IStarkswapV1Pair.baseToken(contract_address=pair_address)
    let (quote_address: felt) = IStarkswapV1Pair.quoteToken(contract_address=pair_address)
    let (curve: felt, _) = IStarkswapV1Pair.curve(contract_address=pair_address)
    let pair: Pair = Pair(base_address, quote_address, pair_address, curve)

    assert pairs[pairs_len] = pair

    return _get_pairs(pairs_len - 1, pairs)

end

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

@external
func setFeeTo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) -> (address: felt):

    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    sv_fee_to.write(address)
    return (address)

end

@external
func setFeeToSetter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) -> (address: felt):

    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    sv_fee_to_setter.write(address)
    return (address)

end

@external
func setPairClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_class_hash: felt
    ) -> (pair_class_hash: felt):

    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    sv_pair_class_hash.write(pair_class_hash)
    return (pair_class_hash)

end

@external
func addCurve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    curve_class_hash: felt
    ) -> (exists: felt):

    with_attr error_message("StarkswapV1Factory: FORBIDDEN"):
        let (caller_address : felt) = get_caller_address()
        let (setter: felt) = sv_fee_to_setter.read()
        assert caller_address = setter
    end

    sv_curve_class_hash.write(curve_class_hash, TRUE)
    return (curve_class_hash)

end

@external
func createPair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_a_address: felt,
    token_b_address: felt,
    curve: felt
    ) -> (pair_address: felt):

    alloc_locals

    with_attr error_message("StarkswapV1Factory: INVALID_CURVE"):
        let (curve_class_hash: felt) = sv_curve_class_hash.read(curve)
        assert curve_class_hash = TRUE
    end

    with_attr error_message("StarkswapV1Factory: IDENTICAL_ADDRESSES"):
        assert_not_equal(token_a_address, token_b_address)
    end

    let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address)

    with_attr error_message("StarkswapV1Factory: ZERO_ADDRESS"):
        assert_not_zero(base_address)
    end

    with_attr error_message("StarkswapV1Factory: PAIR_EXISTS"):
        let (existing_pair: felt) = sv_pair.read(base_address, quote_address, curve)
        assert existing_pair = FALSE
    end

    let (pair_address: felt) = _deploy_starkswap_v1_pair(base_address, quote_address, curve)

    sv_pair.write(base_address, quote_address, curve, pair_address)
    let (length: felt) = sv_pairs_count.read()
    assert_nn(length + 1)
    sv_pair_by_index.write(length, pair_address)
    sv_pairs_count.write(length + 1)

    return (pair_address)

end

func _deploy_starkswap_v1_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_address: felt,
    quote_address: felt,
    curve: felt
    ) -> (contract_address):

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
