%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (get_contract_address, get_caller_address, get_block_timestamp)
from starkware.cairo.common.bool import (TRUE, FALSE)
from starkware.cairo.common.uint256 import (Uint256, uint256_mul, uint256_eq, uint256_sqrt, uint256_lt, uint256_sub, uint256_add, uint256_signed_div_rem, uint256_le)
from starkware.cairo.common.math_cmp import (is_le, is_not_zero)
from starkware.cairo.common.math import (assert_not_equal, assert_not_zero, assert_nn_le, assert_lt)
from contracts.utils.uint import (assert_uint256_zero, assert_uint256_gt, assert_uint256_ge)
from openzeppelin.token.erc20.library import ERC20
from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from contracts.utils.decimals import make_18_dec
from contracts.structs.observation import Observation
from contracts.interfaces.IStarkswapV1Factory import IStarkswapV1Factory
from contracts.interfaces.IStarkswapV1Callee import IStarkswapV1Callee
from contracts.interfaces.IStarkswapV1Curve import IStarkswapV1Curve

# ERC20 mint does not allow `0`, so we use `42` instead
const LOCKING_ADDRESS = 42

# Capture oracle reading every 30 minutes
const PERIOD_SIZE = 1800

@storage_var
func sv_base_token_address() -> (address: felt):
end

@storage_var
func sv_quote_token_address() -> (address: felt):
end

// @audit-info curve class hash
@storage_var
func sv_curve() -> (curve: felt):
end

// @audit-info token reserve
@storage_var
func sv_base_token_reserve() -> (reserve: Uint256):
end

// @audit-info token reserve
@storage_var
func sv_quote_token_reserve() -> (reserve: Uint256):
end

// @audit-info price cumulative last
// @audit-info https://docs.uniswap.org/protocol/V2/concepts/core-concepts/oracles
// @audit using reserves instead of prices, why and what are the implications?
@storage_var
func sv_base_token_reserve_cumulative_last() -> (reserve: Uint256):
end

// @audit-info price cumulative last
// @audit-info https://docs.uniswap.org/protocol/V2/concepts/core-concepts/oracles
// @audit using reserves instead of prices, why and what are the implications?
@storage_var
func sv_quote_token_reserve_cumulative_last() -> (reserve: Uint256):
end

// @audit-info mapping(index) -> Observation
@storage_var
func sv_observations(idx: felt) -> (last: Observation):
end

@storage_var
func sv_observations_len() -> (count: felt):
end

// @audit-info last f(x, y) = K
@storage_var
func sv_k_last() -> (last: Uint256):
end

// @audit-info address of Factory contract
@storage_var
func sv_factory_address() -> (address: felt):
end

// @audit-info timestamp of last observation? last swap?
// @audit there seems to be a bug in the code that sets it.. see comments below
@storage_var
func sv_block_timestamp_last() -> (timestamp: felt):
end

@event
func ev_mint(sender: felt, base_amount: Uint256, quote_amount: Uint256):
end

@event
func ev_burn(sender: felt, base_amount: Uint256, quote_amount: Uint256, to: felt):
end

@event
func ev_swap(sender: felt, base_token_amount_in: Uint256, quote_token_amount_in: Uint256, base_token_amount_out: Uint256, quote_token_amount_out: Uint256, to: felt):
end

@event
func ev_sync(base_token_reserve: Uint256, quote_token_reserve: Uint256):
end

// @audit no check that base_token < quote_token, can it be exploited?
// @audit (it's expected that base_token < quote_token, see sort_tokens)
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(base_token_address: felt, quote_token_address: felt, curve_class_hash: felt):
    // @audit-info msg.sender() is the factory (set the field)
    let (sender) = get_caller_address()
    sv_factory_address.write(sender)

    // @audit-info set token addresses and curve class hash
    sv_base_token_address.write(base_token_address)
    sv_quote_token_address.write(quote_token_address)
    sv_curve.write(curve_class_hash)

    // @audit-info create first Observation with (0, 0)
    let (block_timestamp) = get_block_timestamp()
    sv_observations.write(0, Observation(block_timestamp, Uint256(0, 0), Uint256(0, 0)))
    sv_observations_len.write(1)

    // @audit-info call ERC20 init
    #TODO: name should be "StarkSwap V1 <Curve>" and Symbol should be "<base>/<quote>"
    ERC20.initializer('StarkswapV1', 'StarkswapV1', 18)
    return ()

end

##### ERC20 Getters ######
@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name: felt):
    return ERC20.name()
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol: felt):
    return ERC20.symbol()
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (decimals: felt):
    return ERC20.decimals()
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (totalSupply: Uint256):
    let (total_supply: Uint256) = ERC20.total_supply()
    return (total_supply)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(account: felt) -> (balance: Uint256):
    return ERC20.balance_of(account)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner: felt, spender: felt) -> (remaining: Uint256):
    return ERC20.allowance(owner, spender)
end

##### END ERC20 Getters ######
##### END ERC20 Externals  ######

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(spender: felt, amount: Uint256) -> (success: felt):
    ERC20.approve(spender, amount)
    return (TRUE)
end

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(recipient: felt, amount: Uint256) -> (success: felt):
    ERC20.transfer(recipient, amount)
    return (TRUE)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(sender: felt, recipient: felt, amount: Uint256) -> (success: felt):
    ERC20.transfer_from(sender, recipient, amount)
    return (TRUE)
end


@view
func MINIMUM_LIQUIDITY() -> (minimum: Uint256):
    return (Uint256(1000, 0))
end

// @audit-info get factory address
@view
func factory{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (address: felt):
    return sv_factory_address.read()
end

@view
func baseToken{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (address: felt):
    return sv_base_token_address.read()
end

@view
func quoteToken{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (address: felt):
    return sv_quote_token_address.read()
end

// @audit-info get curve implementation hash and name
@view
func curve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (curve_class_hash: felt, curve_name: felt):
    // @audit read about library_call_*
    let (class_hash) = sv_curve.read()
    let (name) = IStarkswapV1Curve.library_call_name(class_hash)
    return (class_hash, name)
end

// @audit-info get reserves
@view
func getReserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (base_token_reserve: Uint256, quote_token_reserve: Uint256, block_timestamp_last: felt):
    let (base_token_reserve) = sv_base_token_reserve.read()
    let (quote_token_reserve) = sv_quote_token_reserve.read()
    let (timestamp) = sv_block_timestamp_last.read()

    return (base_token_reserve, quote_token_reserve, timestamp)
end

// @audit-info recursive func
// @audit-info @param i - Observation index to start from
// @audit-info @param end_idx - Observation index to end at
// @audit-info @param observations - pointer to array
// @audit-info @return number of collected observations (should be end_idx - i)
// @audit serious issue here..
func _collect_observations{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(i: felt, end_idx: felt, observations: Observation*) -> (count: felt):
    let (observation) = sv_observations.read(i)
    assert [observations] = observation

    if (i) == end_idx:
        return (0)
    end

    // @audit seems like `i` and/or `obervations` don't get advanced..
    let (r) = _collect_observations(i, end_idx, observations)
    return (r + 1)
end

// @audit-info allocs segment and writes Observations to it
@view
func getObservations{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(num_observations: felt) -> (observations_len: felt, observations: Observation*):
    alloc_locals
    let (local observations: Observation*) = alloc()
    let (count) = sv_observations_len.read()

    // @audit-info 0 means collect all observations
    if num_observations == 0:
        _collect_observations(0, count-1, observations)
        return (count, observations)
    else:
        // @audit-info assert count < num_observations
        // @audit shouldn't it be count > num_observations ?
        assert_lt(count, num_observations)
        _collect_observations(count-num_observations, count-1, observations)
        return (num_observations, observations)
    end

end

// @audit-info get last recorded observation
@view
func lastObservation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (observation: Observation):
    let (count) = sv_observations_len.read()
    let (observation) = sv_observations.read(count - 1)

    return (observation)
end

// @audit-info get k_last
@view
func kLast{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (k_last: Uint256):
    let (klast: Uint256) = sv_k_last.read()
    return (klast)
end

// @audit-info if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
// @audit-info minted to `fee_to`
// @audit-info sets k_last to 0 if fees are off
// @audit-info https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol#L88
// @audit-info calculates new K based on reserves params, compares it to k_last field
// @audit new K is calculated by K=x*y, is k_last necessarily calculated like that?
// @audit shouldn't both new K and k_last be calculated according to curve?
func _mint_fee{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    base_token_reserve: Uint256,
    quote_token_reserve: Uint256
) -> (fee_on: felt):
    alloc_locals
    let (factory_address) = factory()
    let (fee_to: felt)    = IStarkswapV1Factory.feeTo(factory_address)

    if fee_to != 0:
        ## Fee is on

        let (k_last: Uint256) = kLast()
        let (is_k_last_zero) = uint256_eq(k_last, Uint256(0, 0))

        if is_k_last_zero != TRUE:
            // @audit-info k = base_token_reserve * quote_token_reserve
            // @audit check OVERFLOW
            // @audit shouldn't k calculation be different according to curve?
            let (k, overflow) = uint256_mul(base_token_reserve, quote_token_reserve)
            assert_uint256_zero(overflow)

            // @audit-info root_k = sqrt(base_token_reserve * quote_token_reserve)
            let (root_k) = uint256_sqrt(k)
            let (root_k_last) = uint256_sqrt(k_last)

            // @audit-info root_k_last < root_k
            let (is_lt) = uint256_lt(root_k_last, root_k)
            if is_lt == TRUE:
                let (total_supply) = totalSupply()

                // @audit-info r0 = root_k - root_k_last
                // @audit check OVERFLOW
                let (r0) = uint256_sub(root_k, root_k_last)
                // @audit-info numerator = total_supply * r0
                let (numerator, overflow) = uint256_mul(total_supply, r0)
                assert_uint256_zero(overflow)

                // @audit-info r1 = root_k * 5
                // @audit check OVERFLOW
                let (r1, overflow) = uint256_mul(root_k, Uint256(5, 0))
                assert_uint256_zero(overflow)
                // @audit-info denominator = r1 * root_k_last
                // @audit check OVERFLOW
                let (denominator, carry) = uint256_add(r1, root_k_last)
                assert carry = 0

                // @audit-info liquidity = numerator / denominator
                // @audit-info liquidity = (total_supply * (root_k - root_k_last)) / (5 * root_k * root_k_last)
                // @audit-info understand this func
                // @audit could we make it div by 0 ?
                let (liquidity, _) = uint256_signed_div_rem(numerator, denominator)
                let (is_liquidity_gt_zero) = uint256_lt(Uint256(0, 0), liquidity)

                if is_liquidity_gt_zero == TRUE:
                    ERC20._mint(fee_to, liquidity)
                    return (TRUE)
                end

                return (TRUE)
            end

            return (TRUE)
        end

        return (TRUE)
    else:
        // @audit-info k_last = 0
        ## Fee is off
        sv_k_last.write(Uint256(0, 0))
        return (FALSE)
    end
end

// @audit-info helper func - write to reserve cumulatives (given from params)
// @audit-info check that:
// @audit-info * we're not in the same block (time_elapsed > 0, there wasn't another call in this block)
// @audit-info * reserves aren't 0
func _update_cumulative_last_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    time_elapsed: felt,
    base_token_reserve: Uint256,
    quote_token_reserve: Uint256,
    base_reserve_cumulative_last: Uint256,
    quote_reserve_cumulative_last: Uint256
):
    alloc_locals
    // @audit-info if time_elapsed != 0 && base_reserve != 0 && quote_reserve != 0
    # if (time_elapsed > 0 && base_reserve != 0 && quote_reserve != 0)
    # ==> if !(time_elapsed <= 0 && base_reserve == 0 && quote_reserve == 0)
    # ==> !(a && b && c) ==> (a + b + c) == 0
    let (is_time_elapsed_le_zero) = is_le(time_elapsed, 0)
    let (is_base_reserve_zero) = uint256_eq(Uint256(0, 0), base_token_reserve)
    let (is_quote_reserve_zero) = uint256_eq(Uint256(0, 0), quote_token_reserve)
    let r0 = is_time_elapsed_le_zero + is_base_reserve_zero
    let r1 = r0 + is_quote_reserve_zero
    if r1 == 0:
        // @audit-info write params to fields
        sv_base_token_reserve_cumulative_last.write(base_reserve_cumulative_last)
        sv_quote_token_reserve_cumulative_last.write(quote_reserve_cumulative_last)
        return ()
    end
    return ()
end

// @audit this func can be called by anyone?? (original is a private function, is this just for testing?)
// @audit-info if sufficient time elapsed, create new Observation
// @audit-info in either case, update *_token_reserve and sv_block_timestamp_last (?? see note below)
// @audit-info https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol#L73
// @audit a lot of problematic things in this func
// @audit * custom Observations code
// @audit * deviations from original func
// @audit * stuff that seems wrong (see notes about `sv_block_timestamp_last`)
@external
func _update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    base_token_balance: Uint256,
    quote_token_balance: Uint256,
    base_token_reserve: Uint256,
    quote_token_reserve: Uint256
) -> ():
    alloc_locals

    // @audit DEVIATION FROM ORIGINAL
    // @audit no overflow check like in the original func
    // @audit in the original func they check that balance params are < max_uint_112 (so that when they're multiplied
    // @audit they're sure to not overflow uint_256 ?)
    // @audit where are the balances multiplied? maybe there's just an overflow check over there?
    // @audit END - DEVIATION FROM ORIGINAL

    let (block_timestamp: felt) = get_block_timestamp()
    let (block_timestamp_last: felt) = sv_block_timestamp_last.read()
    let time_elapsed = block_timestamp - block_timestamp_last

    // @audit-info base_cumulative = base_reserve * time_elapsed
    // @audit-info quote_cumulative = quote_reserve * time_elapsed
    // @audit DEVIATION FROM ORIGINAL
    // @audit in the original code the calculation is:
    // @audit base_cumulative = (base_reserve / quote_reserve) * time_elapsed
    // @audit quote_cumulative = (quote_reserve / base_reserve) * time_elapsed
    // @audit what are the implicataions of this?
    // @audit END - DEVIATION FROM ORIGINAL
    let (base_reserve_cumulative_last,_) = uint256_mul(base_token_reserve, Uint256(time_elapsed, 0))
    let (quote_reserve_cumulative_last,_) = uint256_mul(quote_token_reserve, Uint256(time_elapsed, 0))

    _update_cumulative_last_reserves(time_elapsed, base_token_reserve, quote_token_reserve, base_reserve_cumulative_last, quote_reserve_cumulative_last)

    // @audit how are sv_block_timestamp_last and last_observation.block_timestamp different?
    // @audit last_observation.block_timestamp is REAL
    // @audit sv_block_timestamp_last has PROBLEMS (is always 0)
    let (last_observation) = lastObservation()
    let time_elapsed = block_timestamp - last_observation.block_timestamp

    #if (timeElapsed > periodSize)
    # !(timeElapsed <= periodSize)
    let (is_last_recording_too_recent) = is_le(time_elapsed, PERIOD_SIZE)
    if is_last_recording_too_recent == FALSE:
        // @audit-info this part is done only if !is_last_recording_too_recent
        // @audit CUSTOM OBSERVATION STUFF
        let (observations_len) = sv_observations_len.read()
        sv_observations.write(observations_len, Observation(block_timestamp, base_reserve_cumulative_last, quote_reserve_cumulative_last))
        sv_observations_len.write(observations_len + 1)
        // @audit END - CUSTOM OBSERVATION STUFF

        // @audit-info this part is done in both cases (those three lines repeat below)
        // @audit-info write balances given as params to reserve fields
        sv_base_token_reserve.write(base_token_balance)
        sv_quote_token_reserve.write(quote_token_balance)
        // @audit it seems that block_timestamp_last is assigned to sv_block_timestamp_last again.. was something else meant to be done here?
        // @audit sv_block_timestamp_last is never written to (only here, but it gets the same value as before..)
        // @audit it seems that `_update_cumulative_last_reserves()` above gets wrong values, therefore
        // @audit `sv_*_token_reserve_cumulative_last` and `*_reserve_cumulative_last` above cannot be trusted..
        // @audit `sv_*_token_reserve_cumulative_last` are not used anywhere...
        sv_block_timestamp_last.write(block_timestamp_last)
    else:
        sv_base_token_reserve.write(base_token_balance)
        sv_quote_token_reserve.write(quote_token_balance)
        sv_block_timestamp_last.write(block_timestamp_last)
    end

    ev_sync.emit(base_token_balance, quote_token_balance)
    return ()
end

// @audit this func can be called by anyone?? (or just for testing?)
// @audit-info if total_supply == 0:
// @audit-info   _mint(LOCKING_ADDRESS, MINIMUM_LIQUIDITY()())
// @audit-info   return (liquidity = sqrt(base_token_amount * quote_token_amount) - min_liquidity)
// @audit-info else:
// @audit-info   r1 = base_token_amount * total_supply / base_token_reserve
// @audit-info   r2 = quote_token_amount * total_supply / quote_token_reserve
// @audit-info   return min(r1, r2)
@external
func _calculate_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    total_supply: Uint256,
    base_token_amount: Uint256,
    quote_token_amount: Uint256,
    base_token_reserve: Uint256,
    quote_token_reserve: Uint256
) -> (liquidity: Uint256):
    alloc_locals
    let (is_total_supply_zero) = uint256_eq(total_supply, Uint256(0, 0))
    let (min_liquidity) = MINIMUM_LIQUIDITY()

    if is_total_supply_zero == TRUE:
        // @audit-info r0 = base_token_amount * quote_token_amount
        // @audit check OVERFLOW
        let (r0, overflow) = uint256_mul(base_token_amount, quote_token_amount)
        assert_uint256_zero(overflow)
        // @audit-info r1 = sqrt(r0)
        let (r1) = uint256_sqrt(r0)
        // @audit-info liquidity = r1 - min_liquidity
        // @audit-info liquidity = sqrt(base_token_amount * quote_token_amount) - min_liquidity
        let (liquidity) = uint256_sub(r1, min_liquidity)

        // @audit what is the point of minting to LOCKING_ADDRESS ?
        ERC20._mint(LOCKING_ADDRESS, min_liquidity)
        return (liquidity)
    else:
        // @audit-info tmp0 = base_token_amount * total_supply
        // @audit check OVERFLOW
        let (tmp0, overflow) = uint256_mul(base_token_amount, total_supply)
        assert_uint256_zero(overflow)
        // @audit-info r1 = tmp0 / base_token_reserve
        let (r1, _) = uint256_signed_div_rem(tmp0, base_token_reserve)

        // @audit-info tmp1 = quote_token_amount * total_supply
        // @audit check OVERFLOW
        let (tmp1, overflow) = uint256_mul(quote_token_amount, total_supply)
        assert_uint256_zero(overflow)
        // @audit-info r2 = tmp1 / quote_token_reserve
        let (r2, _) = uint256_signed_div_rem(tmp1, quote_token_reserve)

        // @audit-info return r1 if r1 < r2 else r2
        // @audit-info r1 = base_token_amount * total_supply / base_token_reserve
        // @audit-info r2 = quote_token_amount * total_supply / quote_token_reserve
        let (r1_less_than_r2) = uint256_lt(r1, r2)
        if r1_less_than_r2 == TRUE:
            return (r1)
        else:
            return (r2)
        end
    end
end

// @audit this func can be called by anyone??
// @audit-info sv_k_last = base_token_reserve * quote_token_reserve
@external
func _update_k_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(base_token_reserve: Uint256, quote_token_reserve: Uint256):
    alloc_locals
    // @audit shouldn't k be different according to curve??
    // @audit check OVERFLOW
    let (k_last, overflow) = uint256_mul(base_token_reserve, quote_token_reserve)
    assert_uint256_zero(overflow)
    sv_k_last.write(k_last)
    return ()
end

// @audit-info 
// @audit-info https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol#L109
// @audit original func has reentrancy guard, this does not
@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to: felt) -> (liquidity: Uint256):
    alloc_locals
    let (contract_address) = get_contract_address()

    let (base_token_address) = sv_base_token_address.read()
    let (base_token_reserve) = sv_base_token_reserve.read()
    let (quote_token_address) = sv_quote_token_address.read()
    let (quote_token_reserve) = sv_quote_token_reserve.read()

    // @audit-info get base/quote balances of this contract
    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address)
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address)

    // @audit-info get the base/quote amounts that were deposited to the contract
    // @audit-info base_token_amount = base_token_balance - base_token_reserve
    let (base_token_amount) = uint256_sub(base_token_balance, base_token_reserve)
    // @audit-info quote_token_amount = quote_token_balance - quote_token_reserve
    let (quote_token_amount) = uint256_sub(quote_token_balance, quote_token_reserve)

    // @audit-info pay fees
    let (fee_on) = _mint_fee(base_token_reserve, quote_token_reserve)
    let (total_supply) = totalSupply()

    let (liquidity) = _calculate_liquidity(total_supply, base_token_amount, quote_token_amount, base_token_reserve, quote_token_reserve)

    with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY_MINTED"):
        let (is_liquidity_gt_zero) = uint256_lt(Uint256(0, 0), liquidity)
        assert is_liquidity_gt_zero = TRUE
    end

    // @audit-info mint liquidity to `to` param
    ERC20._mint(to, liquidity)

    // @audit-info if sufficient time elapsed, create new Observation, update reserves
    _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve)

    // @audit-ok why is _update_k_last() only if fee_on == TRUE ?
    // @audit-ok because only if we paid fee (i.e. the fee is on) we'd like to update the k_last (for future
    // @audit-ok fee payments we gotta have the k_last of the last time we paid fees)
    if fee_on == TRUE:
        _update_k_last(base_token_balance, quote_token_balance)
        return (liquidity)
    end

    let (sender) = get_caller_address()
    ev_mint.emit(sender, base_token_amount, quote_token_amount)

    return (liquidity)
end

// @audit-info ### burn pair-token owned by contract, transfer relative base/quote tokens to `to`
// @audit-info base_token_balance = base.balanceOf(this)
// @audit-info quote_token_balance = quote.balanceOf(this)
// @audit-info liquidity = balanceOf(this)
// @audit-info fee_on = _mint_fee(base_token_reserve, quote_token_reserve)
// @audit-info base_token_amount = liquidity * base_token_balance / total_supply
// @audit-info quote_token_amount = liquidity * quote_token_balance / total_supply
// @audit-info assert base_token_amount > 0 && quote_token_amount > 0
// @audit-info ERC20._burn(this_pair_address, liquidity)
// @audit-info IERC20.transfer(base_token_address, to, base_token_amount)
// @audit-info IERC20.transfer(quote_token_address, to, quote_token_amount)
// @audit-info _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve)
// @audit-info if fee_on:
// @audit-info   _update_k_last(base_token_balance, quote_token_balance)
// @audit-info return (base_token_amount, quote_token_amount)
// @audit is `liquidity` right? shouldn't it be `liquidity = balanceOf(to)` ?
// @audit original func has reentrancy guard, this does not
@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to: felt) -> (base_token_amount: Uint256, quote_token_amount: Uint256):
    alloc_locals
    let (this_pair_address) = get_contract_address()

    let (base_token_address) = sv_base_token_address.read()
    let (base_token_reserve) = sv_base_token_reserve.read()
    let (quote_token_address) = sv_quote_token_address.read()
    let (quote_token_reserve) = sv_quote_token_reserve.read()

    let (base_token_balance) = IERC20.balanceOf(base_token_address, this_pair_address)
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, this_pair_address)
    let (liquidity) = balanceOf(this_pair_address)

    // @audit-info mints some pair tokens to the factory
    let (fee_on) = _mint_fee(base_token_reserve, quote_token_reserve)
    let (total_supply) = totalSupply()

    // @audit-info r0 = liquidity * base_token_balance
    let (r0, overflow) = uint256_mul(liquidity, base_token_balance)
    // @audit-info base_token_amount = r0 / total_supply
    let (base_token_amount, _) = uint256_signed_div_rem(r0, total_supply)
    // @audit check OVERFLOW
    assert_uint256_zero(overflow)

    // @audit-info r1 = liquidity * quote_token_balance
    // @audit no OVERFLOW check!
    let (r1, overflow) = uint256_mul(liquidity, quote_token_balance)
    // @audit-info quote_token_amount = r1 / total_supply
    let (quote_token_amount, _) = uint256_signed_div_rem(r1, total_supply)

    // @audit-info assert: base_token_amount > 0 && quote_token_amount > 0
    with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY_BURNED"):
        let (is_base_amout_gt_zero) = uint256_lt(Uint256(0, 0), base_token_amount)
        let (is_quote_amout_gt_zero) = uint256_lt(Uint256(0, 0), quote_token_amount)
        assert is_base_amout_gt_zero + is_quote_amout_gt_zero = 2 #base_amout > 0 && quote_amount > 0
    end

    ERC20._burn(this_pair_address, liquidity)
    // @audit-info base_token_amount = liquidity * base_token_balance / total_supply
    IERC20.transfer(base_token_address, to, base_token_amount)
    // @audit-info quote_token_amount = liquidity * quote_token_balance / total_supply
    IERC20.transfer(quote_token_address, to, quote_token_amount)


    let (base_token_balance) = IERC20.balanceOf(base_token_address, this_pair_address)
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, this_pair_address)

    // @audit-info if sufficient time elapsed, create new Observation, update reserves
    _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve)

    let (sender) = get_caller_address()
    ev_burn.emit(sender, base_token_amount, quote_token_amount, to)

    // @audit why is _update_k_last() only if fee_on == TRUE ?
    if fee_on == TRUE:
        _update_k_last(base_token_balance, quote_token_balance)
        return (base_token_amount, quote_token_amount)
    else:
        return (base_token_amount, quote_token_amount)
    end

end

// @audit-info simple func. transfer base/quote tokens to `to`
func _transfer_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(base_token_address: felt, quote_token_address: felt, base_amount_out: Uint256, quote_amount_out: Uint256, to: felt):
    alloc_locals
    let (is_base_out_gt_zero) = uint256_lt(Uint256(0, 0), base_amount_out)
    let (is_quote_out_gt_zero) = uint256_lt(Uint256(0, 0), quote_amount_out)

    if is_base_out_gt_zero == TRUE:
        IERC20.transfer(base_token_address, to, base_amount_out)
        if is_quote_out_gt_zero == TRUE:
            IERC20.transfer(quote_token_address, to, quote_amount_out)
            return ()
        end
        return ()
    else:
        if is_quote_out_gt_zero == TRUE:
            IERC20.transfer(quote_token_address, to, quote_amount_out)
            return ()
        end
        return ()
    end

end

// @audit-info call `to`'s starkswapV1Call func
// @audit look at implementations of starkswapV1Call
func _invoke_callee{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(base_amount_out: Uint256, quote_amount_out: Uint256, to: felt, calldata_len: felt, calldata: felt*):
    let (has_calldata) = is_not_zero(calldata_len)
    if has_calldata == TRUE:
        let (caller_address) = get_caller_address()
        IStarkswapV1Callee.starkswapV1Call(to, caller_address, base_amount_out, quote_amount_out, calldata_len, calldata)
        return ()
    end
    return ()
end

// @audit-info if balance > (reserve - amount_out):
// @audit-info   return balance - (reserve - amount_out)
// @audit-info else:
// @audit-info   return 0
func _calc_input_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(reserve: Uint256, balance: Uint256, amount_out: Uint256) -> (amount_in: Uint256):
    alloc_locals
    let (r0) = uint256_sub(reserve, amount_out)

    let (is_balance_gt_rt0) = uint256_lt(r0, balance)
    if is_balance_gt_rt0 == TRUE:
        let (r1) = uint256_sub(balance, r0)
        return (r1)
    else:
        return (Uint256(0,0))
    end
end

// @audit-info balance_adjusted = (balance * 1000) - (amount_in * 3)
func _calc_balance_adjusted{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(balance: Uint256, amount_in: Uint256) -> (balance_adjusted: Uint256):
    alloc_locals
    // @audit no OVERFLOW check
    let (r0, _) = uint256_mul(balance, Uint256(1000, 0))
    let (r1, _) = uint256_mul(amount_in, Uint256(3, 0))

    let (res) =  uint256_sub(r0, r1)
    return (res)
end

// @audit-info require(base_amount_out > 0 || quote_amount_out > 0)
// @audit-info require(baseAmout < baseReserve && quoteAmount < quoteReserve)
// @audit-info require(asdfasdf, "INVALID_TO")
// @audit-info base_token.transfer(base_amount_out, to)
// @audit-info quote_token.transfer(quote_amount_out, to)
// @audit-info _invoke_callee(asdfasdf)
// @audit-info base_amount_in = base_token.balanceOf(this) - base_token_reserve + base_amount_out
// @audit-info quote_amount_in = quote_token.balanceOf(this) - quote_token_reserve + quote_amount_out
// @audit-info assert (base_amount_in > 0 || quote_amount_in > 0)
// @audit-info base_token_balance_adjusted = (base_token_balance * 1000) - (base_amount_in * 3)
// @audit-info quote_token_balance_adjusted = (quote_token_balance * 1000) - (quote_amount_in * 3)
// @audit-info base_reserve_adjusted = base_token_reserve * 1000
// @audit-info quote_reserve_adjusted = quote_token_reserve * 1000
// @audit-info # calls normalise_decimals() on both reserve and balance
// @audit-info new_k = IStarkswapV1Curve.library_call_get_k(base_token_balance_adjusted, quote_token_balance_adjusted)
// @audit-info old_k = IStarkswapV1Curve.library_call_get_k(base_reserve_adjusted, quote_reserve_adjusted)
// @audit-info assert (new_k >= old_k)
// @audit-info _update(base_token_balance, quote_token_balance, base_amount_out, quote_amount_out)
// @audit-info https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol#L158
// @audit-ok where is the part where amount_in is transferred?
// @audit-ok called by Router's `swapExactTokensForTokens()` / `swapTokensForExactTokens()`
// @audit original uniswap version has `lock` modifier!!!
@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    base_amount_out: Uint256,
    quote_amount_out: Uint256,
    to: felt,
    calldata_len: felt,
    calldata: felt*
):
    alloc_locals
    let (contract_address) = get_contract_address()

    with_attr error_message("StarkswapV1: INSUFFICIENT_OUTPUT_AMOUNT"):
        # require(base_amount_out > 0 || quote_amount_out > 0)
        let (base_gt_zero) = uint256_lt(Uint256(0, 0), base_amount_out)
        let (quote_gt_zero) = uint256_lt(Uint256(0, 0), quote_amount_out)
        assert_not_zero(base_gt_zero + quote_gt_zero)
    end


    let (base_token_address) = sv_base_token_address.read()
    let (base_token_reserve) = sv_base_token_reserve.read()

    let (quote_token_address) = sv_quote_token_address.read()
    let (quote_token_reserve) = sv_quote_token_reserve.read()

    with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY"):
        # require(baseAmout < baseReserve && quoteAmount < quoteReserve)
        let (p1) = uint256_lt(base_amount_out, base_token_reserve)
        let (p2) = uint256_lt(quote_amount_out, quote_token_reserve)
        assert p1 = 1
        assert p2 = 1
    end

    with_attr error_message("StarkswapV1: INVALID_TO"):
        assert_not_equal(to, base_token_address)
        assert_not_equal(to, quote_token_address)
    end

    // @audit doesn't follow checks-effects-interactions !
    // @audit (gotta find first where the amount_in interaction happens..)
    // @audit look at how Uniswap does it - does it matter if we transfer out or in first?
    // @audit what about if there's an explicit call to the receiver like there is here?
    _transfer_out(base_token_address, quote_token_address, base_amount_out, quote_amount_out, to)
    _invoke_callee(base_amount_out, quote_amount_out, to, calldata_len, calldata)

    let (base_token_decimals) = IERC20.decimals(base_token_address)
    let (quote_token_decimals) = IERC20.decimals(quote_token_address)

    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address)
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address)

    let (base_amount_in) = _calc_input_amount(base_token_reserve, base_token_balance, base_amount_out)
    let (quote_amount_in) = _calc_input_amount(quote_token_reserve, quote_token_balance, quote_amount_out)

    with_attr error_message("StarkswapV1: INSUFFICIENT_INPUT_AMOUNT"):
        #require(base_amount_in > 0 || quote_amount_in > 0)
        let (is_base_in_gt_0) = uint256_lt(Uint256(0, 0), base_amount_in)
        let (is_quote_in_gt_0) = uint256_lt(Uint256(0, 0), quote_amount_in)

        assert_not_zero(is_base_in_gt_0 + is_quote_in_gt_0)
    end


    let (base_token_balance_adjusted) = _calc_balance_adjusted(base_token_balance, base_amount_in)
    let (quote_token_balance_adjusted) = _calc_balance_adjusted(quote_token_balance, quote_amount_in)

    with_attr error_message("StarkswapV1: K"):
        // @audit-ok why is it multiplied by 1000 ?
        // @audit-ok - because_calc_balance_adjusted() above also multiplies by 1000
        let (base_reserve_adjusted, _) = uint256_mul(base_token_reserve, Uint256(1000, 0))
        let (quote_reserve_adjusted, _) = uint256_mul(quote_token_reserve, Uint256(1000, 0))

        // @audit understand how curve-calling mechanism works
        let (class_hash) = sv_curve.read()
        let (a0, b0) = normalise_decimals(base_token_balance_adjusted, quote_token_balance_adjusted, base_token_decimals, quote_token_decimals)
        let (a1, b1) = normalise_decimals(base_reserve_adjusted, quote_reserve_adjusted, base_token_decimals, quote_token_decimals)
        let (new_k) = IStarkswapV1Curve.library_call_get_k(class_hash, a0, b0)
        let (old_k) = IStarkswapV1Curve.library_call_get_k(class_hash, a1, b1)

        // @audit-ok why should K only grow ?
        // @audit-ok - wanna ensure that they're not losing money.. it's okay if k grows, it means that user
        // @audit-ok - deposited more than they should have
        assert_uint256_ge(new_k, old_k)
    end

    // @audit-info if sufficient time elapsed, create new Observation, update reserves
    _update(base_token_balance, quote_token_balance, base_amount_out, quote_amount_out)
    let (sender) = get_caller_address()
    ev_swap.emit(sender, base_amount_in, quote_amount_in, base_amount_out, quote_amount_out, to)

    return ()
end

// @audit-info simple func. simply calls and outputs make_18_dec twice.
func normalise_decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(reserve_a: Uint256, reserve_b: Uint256, decimals_a: felt, decimals_b: felt) -> (reserve_a: Uint256, reserve_b: Uint256):
    alloc_locals
    let (reserve_a_normalised) = make_18_dec(reserve_a, decimals_a)
    let (reserve_b_normalised) = make_18_dec(reserve_b, decimals_b)

    return (reserve_a_normalised, reserve_b_normalised)
end

// @audit-info send token_amount - token_reserve to `to`
// @audit can anybody call this func?
// @audit original func has reentrancy guard, this does not
@external
func skim{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to: felt):
    let (base_token_address) = sv_base_token_address.read()
    let (quote_token_address) = sv_quote_token_address.read()
    let (base_token_reserve) = sv_base_token_reserve.read()
    let (quote_token_reserve) = sv_quote_token_reserve.read()

    let (contract_address) = get_contract_address()

    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address)
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address)

    let (base_token_amount) = uint256_sub(base_token_balance, base_token_reserve)
    let (quote_token_amount) = uint256_sub(quote_token_balance, quote_token_reserve)

    IERC20.transfer(base_token_address, to, base_token_amount)
    IERC20.transfer(quote_token_address, to, quote_token_amount)

    return ()
end

// @audit-info update reserves based on balances
// @audit original func has reentrancy guard, this does not
@external
func sync{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (base_token_address) = sv_base_token_address.read()
    let (quote_token_address) = sv_quote_token_address.read()
    let (base_token_reserve) = sv_base_token_reserve.read()
    let (quote_token_reserve) = sv_quote_token_reserve.read()

    let (contract_address) = get_contract_address()

    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address)
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address)

    // @audit-info if sufficient time elapsed, create new Observation, update reserves
    _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve)

    return ()
end
