%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_contract_address,
    get_caller_address,
    get_block_timestamp,
)
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_add,
    uint256_sqrt,
    uint256_lt,
    uint256_le,
    uint256_check
)
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.math import assert_not_equal, assert_not_zero, assert_nn_le, assert_lt
from contracts.utils.uint import assert_uint256_zero, assert_uint256_gt, assert_uint256_ge
from openzeppelin.token.erc20.library import ERC20
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.upgrades.library import Proxy
from contracts.utils.decimals import make_18_dec
from contracts.structs.observation import Observation
from contracts.interfaces.IStarkswapV1Factory import IStarkswapV1Factory
from contracts.interfaces.IStarkswapV1Callee import IStarkswapV1Callee
from contracts.interfaces.IStarkswapV1Curve import IStarkswapV1Curve

// ERC20 mint does not allow `0`, so we use `42` instead
const LOCKING_ADDRESS = 42;

// Capture oracle reading every 30 minutes
const PERIOD_SIZE = 1800;

@storage_var
func sv_base_token_address() -> (address: felt) {
}

@storage_var
func sv_quote_token_address() -> (address: felt) {
}

@storage_var
func sv_curve() -> (curve: felt) {
}

@storage_var
func sv_base_token_reserve() -> (reserve: Uint256) {
}

@storage_var
func sv_quote_token_reserve() -> (reserve: Uint256) {
}

@storage_var
func sv_base_token_reserve_cumulative_last() -> (reserve: Uint256) {
}

@storage_var
func sv_quote_token_reserve_cumulative_last() -> (reserve: Uint256) {
}

@storage_var
func sv_observations(idx: felt) -> (last: Observation) {
}

@storage_var
func sv_observations_len() -> (count: felt) {
}

@storage_var
func sv_k_last() -> (last: Uint256) {
}

@storage_var
func sv_factory_address() -> (address: felt) {
}

@storage_var
func sv_block_timestamp_last() -> (timestamp: felt) {
}

@storage_var
func sv_reentrancy_lock() -> (locked: felt) {
}

@event
func ev_mint(sender: felt, base_amount: Uint256, quote_amount: Uint256) {
}

@event
func ev_burn(sender: felt, base_amount: Uint256, quote_amount: Uint256, to: felt) {
}

@event
func ev_swap(
    sender: felt,
    base_token_amount_in: Uint256,
    quote_token_amount_in: Uint256,
    base_token_amount_out: Uint256,
    quote_token_amount_out: Uint256,
    to: felt,
) {
}

@event
func ev_sync(base_token_reserve: Uint256, quote_token_reserve: Uint256) {
}

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_address: felt, quote_token_address: felt, curve_class_hash: felt, proxy_admin: felt
) {
    let (sender) = get_caller_address();
    sv_factory_address.write(sender);

    sv_base_token_address.write(base_token_address);
    sv_quote_token_address.write(quote_token_address);
    sv_curve.write(curve_class_hash);

    let (block_timestamp) = get_block_timestamp();
    sv_observations.write(0, Observation(block_timestamp, Uint256(0, 0), Uint256(0, 0)));
    sv_observations_len.write(1);

    // TODO: name should be "StarkSwap V1 <Curve>" and Symbol should be "<base>/<quote>"
    ERC20.initializer('StarkswapV1', 'StarkswapV1', 18);
    Proxy.initializer(proxy_admin);
    return ();
}

// #### ERC20 Getters ######
@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    return ERC20.name();
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    return ERC20.symbol();
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    return ERC20.decimals();
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (total_supply: Uint256) = ERC20.total_supply();
    return (total_supply,);
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    return ERC20.balance_of(account);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    return ERC20.allowance(owner, spender);
}

// #### END ERC20 Getters ######
// #### END ERC20 Externals  ######

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    ERC20.approve(spender, amount);
    return (TRUE,);
}

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer(recipient, amount);
    return (TRUE,);
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer_from(sender, recipient, amount);
    return (TRUE,);
}

@view
func MINIMUM_LIQUIDITY() -> (minimum: Uint256) {
    return (Uint256(1000, 0),);
}

@view
func factory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt) {
    return sv_factory_address.read();
}

@view
func baseToken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return sv_base_token_address.read();
}

@view
func quoteToken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return sv_quote_token_address.read();
}

@view
func curve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    curve_class_hash: felt, curve_name: felt
) {
    let (class_hash) = sv_curve.read();
    let (name) = IStarkswapV1Curve.library_call_name(class_hash);
    return (class_hash, name);
}

@view
func getReserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    base_token_reserve: Uint256, quote_token_reserve: Uint256, block_timestamp_last: felt
) {
    let (base_token_reserve) = sv_base_token_reserve.read();
    let (quote_token_reserve) = sv_quote_token_reserve.read();
    let (timestamp) = sv_block_timestamp_last.read();

    return (base_token_reserve, quote_token_reserve, timestamp);
}

func _collect_observations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    i: felt, end_idx: felt, observations: Observation*
) -> (count: felt) {
    let (observation) = sv_observations.read(i);
    assert [observations] = observation;

    if (i == end_idx+1) {
        return (0,);
    }

    let (r) = _collect_observations(i + 1, end_idx, observations + Observation.SIZE);
    return (r + 1,);
}

@view
func getObservations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    num_observations: felt
) -> (observations_len: felt, observations: Observation*) {
    alloc_locals;
    let (local observations: Observation*) = alloc();
    let (count) = sv_observations_len.read();

    if (num_observations == 0) {
        let (r) = _collect_observations(0, count - 1, observations);
        return (r, observations);
    } else {
        assert_lt(num_observations, count);
        let (r) = _collect_observations(count - num_observations, count - 1, observations);
        return (r, observations);
    }
}

@view
func lastObservation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    observation: Observation
) {
    let (count) = sv_observations_len.read();
    let (observation) = sv_observations.read(count - 1);

    return (observation,);
}

@view
func kLast{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (k_last: Uint256) {
    let (klast: Uint256) = sv_k_last.read();
    return (klast,);
}

func _mint_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_reserve: Uint256, quote_token_reserve: Uint256
) -> (fee_on: felt) {
    alloc_locals;
    let (factory_address) = factory();
    let (fee_to: felt) = IStarkswapV1Factory.feeTo(factory_address);

    if (fee_to != 0) {
        // # Fee is on

        let (k_last: Uint256) = kLast();
        let (is_k_last_zero) = uint256_eq(k_last, Uint256(0, 0));

        if (is_k_last_zero != TRUE) {
            let (k) = SafeUint256.mul(base_token_reserve, quote_token_reserve);

            let (root_k) = uint256_sqrt(k);
            let (root_k_last) = uint256_sqrt(k_last);

            let (is_lt) = uint256_lt(root_k_last, root_k);
            if (is_lt == TRUE) {
                let (total_supply) = totalSupply();

                let (r0) = SafeUint256.sub_le(root_k, root_k_last);
                let (numerator) = SafeUint256.mul(total_supply, r0);

                let (r1) = SafeUint256.mul(root_k, Uint256(5, 0));
                let (denominator) = SafeUint256.add(r1, root_k_last);

                let (liquidity, _) = SafeUint256.div_rem(numerator, denominator);
                let (is_liquidity_gt_zero) = uint256_lt(Uint256(0, 0), liquidity);

                if (is_liquidity_gt_zero == TRUE) {
                    ERC20._mint(fee_to, liquidity);
                    return (TRUE,);
                }

                return (TRUE,);
            }

            return (TRUE,);
        }

        return (TRUE,);
    } else {
        // # Fee is off
        sv_k_last.write(Uint256(0, 0));
        return (FALSE,);
    }
}

func _update_cumulative_last_reserves{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    time_elapsed: felt,
    base_token_reserve: Uint256,
    quote_token_reserve: Uint256,
    base_reserve_cumulative_last: Uint256,
    quote_reserve_cumulative_last: Uint256,
) {
    alloc_locals;
    // if (time_elapsed > 0 && base_reserve != 0 && quote_reserve != 0)
    // ==> if !(time_elapsed <= 0 && base_reserve == 0 && quote_reserve == 0)
    // ==> !(a && b && c) ==> (a + b + c) == 0
    let is_time_elapsed_le_zero = is_le(time_elapsed, 0);
    let (is_base_reserve_zero) = uint256_eq(Uint256(0, 0), base_token_reserve);
    let (is_quote_reserve_zero) = uint256_eq(Uint256(0, 0), quote_token_reserve);
    let r0 = is_time_elapsed_le_zero + is_base_reserve_zero;
    let r1 = r0 + is_quote_reserve_zero;
    if (r1 == 0) {
        sv_base_token_reserve_cumulative_last.write(base_reserve_cumulative_last);
        sv_quote_token_reserve_cumulative_last.write(quote_reserve_cumulative_last);
        return ();
    }
    return ();
}

func _update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_balance: Uint256,
    quote_token_balance: Uint256,
    base_token_reserve: Uint256,
    quote_token_reserve: Uint256,
) -> () {
    alloc_locals;
    with_attr error_message("StarkswapV1: amount is not a valid Uint256") {
        uint256_check(base_token_balance);
        uint256_check(quote_token_balance);
        uint256_check(base_token_reserve);
        uint256_check(quote_token_reserve);
    }
    let (block_timestamp: felt) = get_block_timestamp();
    let (block_timestamp_last: felt) = sv_block_timestamp_last.read();
    let time_elapsed = block_timestamp - block_timestamp_last;

    let (base_reserve_cumulative_last_old) = sv_base_token_reserve_cumulative_last.read();
    let (quote_reserve_cumulative_last_old) = sv_quote_token_reserve_cumulative_last.read();

    let (base_reserve_cumulative_last) = SafeUint256.mul(
        base_token_reserve, Uint256(time_elapsed, 0)
    );
    let (quote_reserve_cumulative_last) = SafeUint256.mul(
        quote_token_reserve, Uint256(time_elapsed, 0)
    );

    let (base_reserve_cumulative_last, _) = uint256_add(base_reserve_cumulative_last, base_reserve_cumulative_last_old);
    let (quote_reserve_cumulative_last, _) = uint256_add(quote_reserve_cumulative_last, quote_reserve_cumulative_last_old);

    _update_cumulative_last_reserves(
        time_elapsed,
        base_token_reserve,
        quote_token_reserve,
        base_reserve_cumulative_last,
        quote_reserve_cumulative_last,
    );

    let (last_observation) = lastObservation();
    let time_elapsed = block_timestamp - last_observation.block_timestamp;

    // if (timeElapsed > periodSize)
    // !(timeElapsed <= periodSize)
    let is_last_recording_too_recent = is_le(time_elapsed, PERIOD_SIZE);
    if (is_last_recording_too_recent == FALSE) {
        let (observations_len) = sv_observations_len.read();
        sv_observations.write(
            observations_len,
            Observation(block_timestamp, base_reserve_cumulative_last, quote_reserve_cumulative_last),
        );
        sv_observations_len.write(observations_len + 1);

        sv_base_token_reserve.write(base_token_balance);
        sv_quote_token_reserve.write(quote_token_balance);
        sv_block_timestamp_last.write(block_timestamp);
    } else {
        sv_base_token_reserve.write(base_token_balance);
        sv_quote_token_reserve.write(quote_token_balance);
        sv_block_timestamp_last.write(block_timestamp);
    }

    ev_sync.emit(base_token_balance, quote_token_balance);
    return ();
}

func _calculate_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    total_supply: Uint256,
    base_token_amount: Uint256,
    quote_token_amount: Uint256,
    base_token_reserve: Uint256,
    quote_token_reserve: Uint256,
) -> (liquidity: Uint256) {
    alloc_locals;
    let (is_total_supply_zero) = uint256_eq(total_supply, Uint256(0, 0));
    let (min_liquidity) = MINIMUM_LIQUIDITY();

    if (is_total_supply_zero == TRUE) {
        let (r0) = SafeUint256.mul(base_token_amount, quote_token_amount);
        let (r1) = uint256_sqrt(r0);
        let (liquidity) = SafeUint256.sub_lt(r1, min_liquidity);

        ERC20._mint(LOCKING_ADDRESS, min_liquidity);
        return (liquidity,);
    } else {
        let (tmp0) = SafeUint256.mul(base_token_amount, total_supply);
        let (r1, _) = SafeUint256.div_rem(tmp0, base_token_reserve);

        let (tmp1) = SafeUint256.mul(quote_token_amount, total_supply);
        let (r2, _) = SafeUint256.div_rem(tmp1, quote_token_reserve);

        let (r1_less_than_r2) = uint256_lt(r1, r2);
        if (r1_less_than_r2 == TRUE) {
            return (r1,);
        } else {
            return (r2,);
        }
    }
}

func _update_k_last{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_reserve: Uint256, quote_token_reserve: Uint256
) {
    alloc_locals;
    with_attr error_message("StarkswapV1: amount is not a valid Uint256") {
        uint256_check(base_token_reserve);
        uint256_check(quote_token_reserve);
    }
    let (k_last) = SafeUint256.mul(base_token_reserve, quote_token_reserve);
    sv_k_last.write(k_last);
    return ();
}

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt) -> (
    liquidity: Uint256
) {
    alloc_locals;
    _lock();
    let (contract_address) = get_contract_address();

    let (base_token_address) = sv_base_token_address.read();
    let (base_token_reserve) = sv_base_token_reserve.read();
    let (quote_token_address) = sv_quote_token_address.read();
    let (quote_token_reserve) = sv_quote_token_reserve.read();

    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address);
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address);

    let (base_token_amount) = SafeUint256.sub_lt(base_token_balance, base_token_reserve);
    let (quote_token_amount) = SafeUint256.sub_lt(quote_token_balance, quote_token_reserve);

    let (fee_on) = _mint_fee(base_token_reserve, quote_token_reserve);
    let (total_supply) = totalSupply();

    let (liquidity) = _calculate_liquidity(
        total_supply, base_token_amount, quote_token_amount, base_token_reserve, quote_token_reserve
    );

    with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY_MINTED") {
        let (is_liquidity_gt_zero) = uint256_lt(Uint256(0, 0), liquidity);
        assert is_liquidity_gt_zero = TRUE;
    }

    ERC20._mint(to, liquidity);

    _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

    if (fee_on == TRUE) {
        _update_k_last(base_token_balance, quote_token_balance);
        _unlock();
        return (liquidity,);
    }

    let (sender) = get_caller_address();
    ev_mint.emit(sender, base_token_amount, quote_token_amount);

    _unlock();
    return (liquidity,);
}

@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt) -> (
    base_token_amount: Uint256, quote_token_amount: Uint256
) {
    alloc_locals;
    _lock();
    let (this_pair_address) = get_contract_address();

    let (base_token_address) = sv_base_token_address.read();
    let (base_token_reserve) = sv_base_token_reserve.read();
    let (quote_token_address) = sv_quote_token_address.read();
    let (quote_token_reserve) = sv_quote_token_reserve.read();

    let (base_token_balance) = IERC20.balanceOf(base_token_address, this_pair_address);
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, this_pair_address);
    let (liquidity) = balanceOf(this_pair_address);

    let (fee_on) = _mint_fee(base_token_reserve, quote_token_reserve);
    let (total_supply) = totalSupply();

    let (r0) = SafeUint256.mul(liquidity, base_token_balance);
    let (base_token_amount, _) = SafeUint256.div_rem(r0, total_supply);

    let (r1) = SafeUint256.mul(liquidity, quote_token_balance);
    let (quote_token_amount, _) = SafeUint256.div_rem(r1, total_supply);

    with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY_BURNED") {
        let (is_base_amout_gt_zero) = uint256_lt(Uint256(0, 0), base_token_amount);
        let (is_quote_amout_gt_zero) = uint256_lt(Uint256(0, 0), quote_token_amount);
        assert is_base_amout_gt_zero + is_quote_amout_gt_zero = 2;  // base_amout > 0 && quote_amount > 0
    }

    ERC20._burn(this_pair_address, liquidity);
    IERC20.transfer(base_token_address, to, base_token_amount);
    IERC20.transfer(quote_token_address, to, quote_token_amount);

    let (base_token_balance) = IERC20.balanceOf(base_token_address, this_pair_address);
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, this_pair_address);

    _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

    let (sender) = get_caller_address();
    ev_burn.emit(sender, base_token_amount, quote_token_amount, to);

    if (fee_on == TRUE) {
        _update_k_last(base_token_balance, quote_token_balance);
        _unlock();
        return (base_token_amount, quote_token_amount);
    } else {
        _unlock();
        return (base_token_amount, quote_token_amount);
    }
}

func _transfer_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token_address: felt,
    quote_token_address: felt,
    base_amount_out: Uint256,
    quote_amount_out: Uint256,
    to: felt,
) {
    alloc_locals;
    let (is_base_out_gt_zero) = uint256_lt(Uint256(0, 0), base_amount_out);
    let (is_quote_out_gt_zero) = uint256_lt(Uint256(0, 0), quote_amount_out);

    if (is_base_out_gt_zero == TRUE) {
        IERC20.transfer(base_token_address, to, base_amount_out);
        if (is_quote_out_gt_zero == TRUE) {
            IERC20.transfer(quote_token_address, to, quote_amount_out);
            return ();
        }
        return ();
    } else {
        if (is_quote_out_gt_zero == TRUE) {
            IERC20.transfer(quote_token_address, to, quote_amount_out);
            return ();
        }
        return ();
    }
}

func _lock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (is_locked) = sv_reentrancy_lock.read();
    with_attr error_message("StarkswapV1: LOCKED") {
        assert is_locked = 0;
    }
    sv_reentrancy_lock.write(1);

    return();
}

func _unlock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (is_locked) = sv_reentrancy_lock.read();
    assert is_locked = 1;
    sv_reentrancy_lock.write(0);

    return();
}

func _invoke_callee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_amount_out: Uint256,
    quote_amount_out: Uint256,
    to: felt,
    calldata_len: felt,
    calldata: felt*,
) {
    let has_calldata = is_not_zero(calldata_len);
    if (has_calldata == TRUE) {
        let (caller_address) = get_caller_address();
        IStarkswapV1Callee.starkswapV1Call(
            to, caller_address, base_amount_out, quote_amount_out, calldata_len, calldata
        );
        return ();
    }
    return ();
}

func _calc_input_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    reserve: Uint256, balance: Uint256, amount_out: Uint256
) -> (amount_in: Uint256) {
    alloc_locals;
    let (r0) = SafeUint256.sub_le(reserve, amount_out);

    let (is_balance_gt_rt0) = uint256_lt(r0, balance);
    if (is_balance_gt_rt0 == TRUE) {
        let (r1) = SafeUint256.sub_le(balance, r0);
        return (r1,);
    } else {
        return (Uint256(0, 0),);
    }
}

func _calc_balance_adjusted{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    balance: Uint256, amount_in: Uint256
) -> (balance_adjusted: Uint256) {
    alloc_locals;
    let (r0) = SafeUint256.mul(balance, Uint256(1000, 0));
    let (r1) = SafeUint256.mul(amount_in, Uint256(3, 0));

    let (res) = SafeUint256.sub_le(r0, r1);
    return (res,);
}

@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_amount_out: Uint256,
    quote_amount_out: Uint256,
    to: felt,
    calldata_len: felt,
    calldata: felt*,
) {
    alloc_locals;
    with_attr error_message("StarkswapV1: amount is not a valid Uint256") {
        uint256_check(base_amount_out);
        uint256_check(quote_amount_out);
    }
    _lock();
    let (contract_address) = get_contract_address();

    with_attr error_message("StarkswapV1: INSUFFICIENT_OUTPUT_AMOUNT") {
        // require(base_amount_out > 0 || quote_amount_out > 0)
        let (base_gt_zero) = uint256_lt(Uint256(0, 0), base_amount_out);
        let (quote_gt_zero) = uint256_lt(Uint256(0, 0), quote_amount_out);
        assert_not_zero(base_gt_zero + quote_gt_zero);
    }

    let (base_token_address) = sv_base_token_address.read();
    let (base_token_reserve) = sv_base_token_reserve.read();

    let (quote_token_address) = sv_quote_token_address.read();
    let (quote_token_reserve) = sv_quote_token_reserve.read();

    with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY") {
        // require(baseAmout < baseReserve && quoteAmount < quoteReserve)
        let (p1) = uint256_lt(base_amount_out, base_token_reserve);
        let (p2) = uint256_lt(quote_amount_out, quote_token_reserve);
        assert p1 = 1;
        assert p2 = 1;
    }

    with_attr error_message("StarkswapV1: INVALID_TO") {
        assert_not_equal(to, base_token_address);
        assert_not_equal(to, quote_token_address);
    }

    _transfer_out(base_token_address, quote_token_address, base_amount_out, quote_amount_out, to);
    _invoke_callee(base_amount_out, quote_amount_out, to, calldata_len, calldata);

    let (base_token_decimals) = IERC20.decimals(base_token_address);
    let (quote_token_decimals) = IERC20.decimals(quote_token_address);

    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address);
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address);

    let (base_amount_in) = _calc_input_amount(
        base_token_reserve, base_token_balance, base_amount_out
    );
    let (quote_amount_in) = _calc_input_amount(
        quote_token_reserve, quote_token_balance, quote_amount_out
    );

    with_attr error_message("StarkswapV1: INSUFFICIENT_INPUT_AMOUNT") {
        // require(base_amount_in > 0 || quote_amount_in > 0)
        let (is_base_in_gt_0) = uint256_lt(Uint256(0, 0), base_amount_in);
        let (is_quote_in_gt_0) = uint256_lt(Uint256(0, 0), quote_amount_in);

        assert_not_zero(is_base_in_gt_0 + is_quote_in_gt_0);
    }

    let (base_token_balance_adjusted) = _calc_balance_adjusted(base_token_balance, base_amount_in);
    let (quote_token_balance_adjusted) = _calc_balance_adjusted(
        quote_token_balance, quote_amount_in
    );

    with_attr error_message("StarkswapV1: K") {
        let (base_reserve_adjusted) = SafeUint256.mul(base_token_reserve, Uint256(1000, 0));
        let (quote_reserve_adjusted) = SafeUint256.mul(quote_token_reserve, Uint256(1000, 0));

        let (class_hash) = sv_curve.read();
        let (a0, b0) = normalise_decimals(
            base_token_balance_adjusted,
            quote_token_balance_adjusted,
            base_token_decimals,
            quote_token_decimals,
        );
        let (a1, b1) = normalise_decimals(
            base_reserve_adjusted, quote_reserve_adjusted, base_token_decimals, quote_token_decimals
        );
        let (new_k) = IStarkswapV1Curve.library_call_get_k(class_hash, a0, b0);
        let (old_k) = IStarkswapV1Curve.library_call_get_k(class_hash, a1, b1);

        assert_uint256_ge(new_k, old_k);
    }

    _update(base_token_balance, quote_token_balance, base_amount_out, quote_amount_out);
    let (sender) = get_caller_address();
    ev_swap.emit(sender, base_amount_in, quote_amount_in, base_amount_out, quote_amount_out, to);

    _unlock();
    return ();
}

func normalise_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    reserve_a: Uint256, reserve_b: Uint256, decimals_a: felt, decimals_b: felt
) -> (reserve_a: Uint256, reserve_b: Uint256) {
    alloc_locals;
    let (reserve_a_normalised) = make_18_dec(reserve_a, decimals_a);
    let (reserve_b_normalised) = make_18_dec(reserve_b, decimals_b);

    return (reserve_a_normalised, reserve_b_normalised);
}

@external
func skim{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt) {
    _lock();
    let (base_token_address) = sv_base_token_address.read();
    let (quote_token_address) = sv_quote_token_address.read();
    let (base_token_reserve) = sv_base_token_reserve.read();
    let (quote_token_reserve) = sv_quote_token_reserve.read();

    let (contract_address) = get_contract_address();

    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address);
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address);

    let (base_token_amount) = SafeUint256.sub_lt(base_token_balance, base_token_reserve);
    let (quote_token_amount) = SafeUint256.sub_lt(quote_token_balance, quote_token_reserve);

    IERC20.transfer(base_token_address, to, base_token_amount);
    IERC20.transfer(quote_token_address, to, quote_token_amount);

    _unlock();
    return ();
}

@external
func sync{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    _lock();
    let (base_token_address) = sv_base_token_address.read();
    let (quote_token_address) = sv_quote_token_address.read();
    let (base_token_reserve) = sv_base_token_reserve.read();
    let (quote_token_reserve) = sv_quote_token_reserve.read();

    let (contract_address) = get_contract_address();

    let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address);
    let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address);

    _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

    _unlock();
    return ();
}
