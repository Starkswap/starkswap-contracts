#[contract]
mod StarkswapV1Pair {
    use starkswap_contracts::structs::observation::Observation;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1Curve;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1Factory;
    use starkswap_contracts::utils::decimals::make_18_dec;
    use starkswap_contracts::ierc20::IERC20;
    use starkswap_contracts::ierc20::IERC20DispatcherTrait;
    use starkswap_contracts::ierc20::IERC20Dispatcher;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use zeroable::Zeroable;
    use integer::u256_from_felt252;
    use integer::u256_sqrt;

    const LOCKING_ADDRESS: felt252 = 42; // ERC20 mint does not allow `0`, so we use `42` instead
    const PERIOD_SIZE: felt252 = 1800; // Capture oracle reading every 30 minutes

    struct Storage {
        sv_base_token_address: ContractAddress,
        sv_quote_token_address: ContractAddress,
        sv_curve: felt252,
        sv_base_token_reserve: u256,
        sv_quote_token_reserve: u256,
        sv_base_token_reserve_cumulative_last: u256,
        sv_quote_token_reserve_cumulative_last: u256,
        //sv_observations: LegacyMap::<felt252, Observation>,
        sv_observations_len: felt252,
        sv_k_last: u256,
        sv_factory_address: ContractAddress,
        sv_block_timestamp_last: u64,
        sv_reentrancy_lock: bool,
    }

    #[event]
    fn ev_mint(sender: ContractAddress, base_amount: u256, quote_amount: u256) {}

    #[event]
    fn ev_burn(
        sender: ContractAddress, base_amount: u256, quote_amount: u256, to: ContractAddress
    ) {}

    #[event]
    fn ev_swap(
        sender: ContractAddress,
        base_token_amount_in: u256,
        quote_token_amount_in: u256,
        base_token_amount_out: u256,
        quote_token_amount_out: u256,
        to: ContractAddress,
    ) {}

    #[event]
    fn ev_sync(base_token_reserve: u256, quote_token_reserve: u256) {}

    #[constructor]
    fn constructor(
        base_token_address: ContractAddress,
        quote_token_address: ContractAddress,
        curve_class_hash: felt252
    ) {
        let sender: ContractAddress = get_caller_address();
        sv_factory_address::write(sender);

        sv_base_token_address::write(base_token_address);
        sv_quote_token_address::write(quote_token_address);
        sv_curve::write(curve_class_hash);

        let block_timestamp = get_block_timestamp();
    //sv_observations::write(0, Observation(block_timestamp, u256(0, 0), u256(0, 0)));
    //sv_observations_len::write(1);

    // TODO: name should be "StarkSwap V1 <Curve>" and Symbol should be "<base>/<quote>"
    //ERC20.initializer('StarkswapV1', 'StarkswapV1', 18);
    }

    // #### ERC20 Getters ######
    //#[view]
    //fn name() -> felt252 {
    //return ERC20.name();
    //}

    //#[view]
    //fn symbol() -> felt252 {
    //return ERC20.symbol();
    //}

    //#[view]
    //fn decimals() -> felt252 {
    //return ERC20.decimals();
    //}

    #[view]
    fn totalSupply() -> u256 {
        //TODO: fix
        //return ERC20.total_supply();
        return u256_from_felt252(0);
    }

    //#[view]
    //fn balanceOf(account: felt252) -> u256 {
    //return ERC20.balance_of(account);
    //}

    //#[view]
    //fn allowance(owner: felt252, spender: felt252) -> u256 {
    //return ERC20.allowance(owner, spender);
    //}

    //// #### END ERC20 Getters ######
    //// #### END ERC20 Externals  ######

    //#[external]
    //fn approve(spender: ContractAddress, amount: u256) -> bool {
    //ERC20.approve(spender, amount);
    //return true;
    //}

    //#[external]
    //fn transfer(recipient: ContractAddress, amount: u256) -> bool {
    //ERC20.transfer(recipient, amount);
    //return true;
    //}

    //#[external]
    //fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
    //ERC20.transfer_from(sender, recipient, amount);
    //return true;
    //}

    #[view]
    fn MINIMUM_LIQUIDITY() -> u256 {
        return u256_from_felt252(1000);
    }

    #[view]
    fn factory() -> ContractAddress {
        return sv_factory_address::read();
    }

    #[view]
    fn baseToken() -> ContractAddress {
        return sv_base_token_address::read();
    }

    #[view]
    fn quoteToken() -> ContractAddress {
        return sv_quote_token_address::read();
    }

    #[view]
    fn curve() -> (felt252, felt252) {
        let class_hash = sv_curve::read();
        //TODO: figure out how library_call works
        //let name = IStarkswapV1Curve::library_call_name(class_hash);
        //return (class_hash, name);
        return (class_hash, 'foo');
    }

    #[view]
    fn getReserves() -> (u256, u256, u64) {
        let base_token_reserve = sv_base_token_reserve::read();
        let quote_token_reserve = sv_quote_token_reserve::read();
        let timestamp = sv_block_timestamp_last::read();

        return (base_token_reserve, quote_token_reserve, timestamp);
    }
    // fn _collect_observations(
    //     i: felt252, end_idx: felt252, observations: Observation*
    // ) -> (count: felt252) {
    //     let (observation) = sv_observations::read(i);
    //     assert [observations] = observation;

    //     if ((i) == end_idx) {
    //         return (0,);
    //     }

    //     let (r) = _collect_observations(i, end_idx, observations);
    //     return (r + 1,);
    // }

    // #[view]
    // fn getObservations(
    //     num_observations: felt252
    // ) -> (observations_len: felt252, observations: Observation*) {
    //     alloc_locals;
    //     let (local observations: Observation*) = alloc();
    //     let (count) = sv_observations_len::read();

    //     if (num_observations == 0) {
    //         _collect_observations(0, count - 1, observations);
    //         return (count, observations);
    //     } else {
    //         assert_lt(count, num_observations);
    //         _collect_observations(count - num_observations, count - 1, observations);
    //         return (num_observations, observations);
    //     }
    // }

     #[view]
     fn lastObservation() -> Observation {
         //let count = sv_observations_len::read();
         //let observation = sv_observations::read(count - 1);

         //return observation;
         return Observation {
            block_timestamp: 0,
            cumulative_base_reserve: u256_from_felt252(0),
            cumulative_quote_reserve: u256_from_felt252(0)
         };
     }

    #[view]
    fn kLast() -> u256 {
        return sv_k_last::read();
    }

    fn _mint_fee(base_token_reserve: u256, quote_token_reserve: u256) -> bool {
        let factory_address = factory();
        //TODO: fix
        //let fee_to: ContractAddress = IStarkswapV1Factory::feeTo(factory_address);
        let fee_to: ContractAddress = Zeroable::zero();

        if (fee_to != Zeroable::zero()) {
            // # Fee is on

            let k_last: u256 = kLast();
            if (k_last != u256_from_felt252(
                0
            )) {
                //TODO: replace with curve get_k?
                let k = base_token_reserve * quote_token_reserve;

                let root_k = u256 { low: u256_sqrt(k), high: 0_u128 };
                let root_k_last = u256 { low: u256_sqrt(k_last), high: 0_u128 };

                if (root_k_last < root_k) {
                    let total_supply = totalSupply();

                    let r0 = root_k - root_k_last;
                    let numerator = total_supply * r0;

                    let r1 = root_k * u256_from_felt252(5);
                    let denominator = r1 + root_k_last;

                    let liquidity = numerator / denominator;

                    if (liquidity > u256_from_felt252(0)) { //TODO: fix
                    //ERC20._mint(fee_to, liquidity);
                    }
                }
            }
            return true;
        } else {
            // # Fee is off
            sv_k_last::write(u256_from_felt252(0));
            return false;
        }
    }

    fn _update_cumulative_last_reserves(
        time_elapsed: felt252,
        base_token_reserve: u256,
        quote_token_reserve: u256,
        base_reserve_cumulative_last: u256,
        quote_reserve_cumulative_last: u256
    ) {
        // if (time_elapsed > 0 && base_reserve != 0 && quote_reserve != 0)
        if (u256_from_felt252(
            time_elapsed
        ) > u256_from_felt252(
            0
        )) {
            if (base_token_reserve != u256_from_felt252(
                0
            )) {
                if (quote_token_reserve != u256_from_felt252(
                    0
                )) {
                    sv_base_token_reserve_cumulative_last::write(base_reserve_cumulative_last);
                    sv_quote_token_reserve_cumulative_last::write(quote_reserve_cumulative_last);
                }
            }
        }
    }


 fn _update(
     base_token_balance: u256,
     quote_token_balance: u256,
     base_token_reserve: u256,
     quote_token_reserve: u256
) -> () {
     //let block_timestamp = get_block_timestamp();
     //let block_timestamp_last = sv_block_timestamp_last::read();
     //let time_elapsed = block_timestamp - block_timestamp_last;

     //let base_reserve_cumulative_last_old = sv_base_token_reserve_cumulative_last::read();
     //let quote_reserve_cumulative_last_old = sv_quote_token_reserve_cumulative_last::read();

     //let base_reserve_cumulative_last = base_token_reserve * u256_from_felt252(time_elapsed);
     //let quote_reserve_cumulative_last = quote_token_reserve * u256_from_felt252(time_elapsed);

     //let base_reserve_cumulative_last = base_reserve_cumulative_last + base_reserve_cumulative_last_old;
     //let quote_reserve_cumulative_last = quote_reserve_cumulative_last + quote_reserve_cumulative_last_old;

     //_update_cumulative_last_reserves(
         //time_elapsed,
         //base_token_reserve,
         //quote_token_reserve,
         //base_reserve_cumulative_last,
         //quote_reserve_cumulative_last,
     //);

     //let last_observation = lastObservation();
     //let time_elapsed = block_timestamp - last_observation.block_timestamp;

     //// if (timeElapsed > periodSize)
     //// !(timeElapsed <= periodSize)
     //if (time_elapsed > PERIOD_SIZE) {
        ////TODO: write observations
         ////let (observations_len) = sv_observations_len::read();
         ////sv_observations::write(
             ////observations_len,
             ////Observation(block_timestamp, base_reserve_cumulative_last, quote_reserve_cumulative_last),
         ////);
         ////sv_observations_len::write(observations_len + 1);

         //sv_base_token_reserve::write(base_token_balance);
         //sv_quote_token_reserve::write(quote_token_balance);
         //sv_block_timestamp_last::write(block_timestamp);
     //} else {
         //sv_base_token_reserve::write(base_token_balance);
         //sv_quote_token_reserve::write(quote_token_balance);
         //sv_block_timestamp_last::write(block_timestamp);
     //}

     //ev_sync(base_token_balance, quote_token_balance);
 }

// fn _calculate_liquidity(
//     total_supply: u256,
//     base_token_amount: u256,
//     quote_token_amount: u256,
//     base_token_reserve: u256,
//     quote_token_reserve: u256,
// ) -> (liquidity: u256) {
//     alloc_locals;
//     let (is_total_supply_zero) = uint256_eq(total_supply, u256(0, 0));
//     let (min_liquidity) = MINIMUM_LIQUIDITY();

//     if (is_total_supply_zero == TRUE) {
//         let (r0) = SafeUint256.mul(base_token_amount, quote_token_amount);
//         let (r1) = uint256_sqrt(r0);
//         let (liquidity) = SafeUint256.sub_lt(r1, min_liquidity);

//         ERC20._mint(LOCKING_ADDRESS, min_liquidity);
//         return (liquidity,);
//     } else {
//         let (tmp0) = SafeUint256.mul(base_token_amount, total_supply);
//         let (r1, _) = SafeUint256.div_rem(tmp0, base_token_reserve);

//         let (tmp1) = SafeUint256.mul(quote_token_amount, total_supply);
//         let (r2, _) = SafeUint256.div_rem(tmp1, quote_token_reserve);

//         let (r1_less_than_r2) = uint256_lt(r1, r2);
//         if (r1_less_than_r2 == TRUE) {
//             return (r1,);
//         } else {
//             return (r2,);
//         }
//     }
// }

// fn _update_k_last(
//     base_token_reserve: u256, quote_token_reserve: u256
// ) {
//     alloc_locals;
//     with_attr error_message("StarkswapV1: amount is not a valid u256") {
//         uint256_check(base_token_reserve);
//         uint256_check(quote_token_reserve);
//     }
//     let (k_last) = SafeUint256.mul(base_token_reserve, quote_token_reserve);
//     sv_k_last::write(k_last);
//     return ();
// }

// #[external]
// fn mint(to: felt252) -> (
//     liquidity: u256
// ) {
//     alloc_locals;
//     _lock();
//     let (contract_address) = get_contract_address();

//     let (base_token_address) = sv_base_token_address::read();
//     let (base_token_reserve) = sv_base_token_reserve::read();
//     let (quote_token_address) = sv_quote_token_address::read();
//     let (quote_token_reserve) = sv_quote_token_reserve::read();

//     let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address);
//     let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address);

//     let (base_token_amount) = SafeUint256.sub_lt(base_token_balance, base_token_reserve);
//     let (quote_token_amount) = SafeUint256.sub_lt(quote_token_balance, quote_token_reserve);

//     let (fee_on) = _mint_fee(base_token_reserve, quote_token_reserve);
//     let (total_supply) = totalSupply();

//     let (liquidity) = _calculate_liquidity(
//         total_supply, base_token_amount, quote_token_amount, base_token_reserve, quote_token_reserve
//     );

//     with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY_MINTED") {
//         let (is_liquidity_gt_zero) = uint256_lt(u256(0, 0), liquidity);
//         assert is_liquidity_gt_zero = TRUE;
//     }

//     ERC20._mint(to, liquidity);

//     _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

//     if (fee_on == TRUE) {
//         _update_k_last(base_token_balance, quote_token_balance);
//         _unlock();
//         return (liquidity,);
//     }

//     let (sender) = get_caller_address();
//     ev_mint.emit(sender, base_token_amount, quote_token_amount);

//     _unlock();
//     return (liquidity,);
// }

// #[external]
// fn burn(to: felt252) -> (
//     base_token_amount: u256, quote_token_amount: u256
// ) {
//     alloc_locals;
//     _lock();
//     let (this_pair_address) = get_contract_address();

//     let (base_token_address) = sv_base_token_address::read();
//     let (base_token_reserve) = sv_base_token_reserve::read();
//     let (quote_token_address) = sv_quote_token_address::read();
//     let (quote_token_reserve) = sv_quote_token_reserve::read();

//     let (base_token_balance) = IERC20.balanceOf(base_token_address, this_pair_address);
//     let (quote_token_balance) = IERC20.balanceOf(quote_token_address, this_pair_address);
//     let (liquidity) = balanceOf(this_pair_address);

//     let (fee_on) = _mint_fee(base_token_reserve, quote_token_reserve);
//     let (total_supply) = totalSupply();

//     let (r0) = SafeUint256.mul(liquidity, base_token_balance);
//     let (base_token_amount, _) = SafeUint256.div_rem(r0, total_supply);

//     let (r1) = SafeUint256.mul(liquidity, quote_token_balance);
//     let (quote_token_amount, _) = SafeUint256.div_rem(r1, total_supply);

//     with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY_BURNED") {
//         let (is_base_amout_gt_zero) = uint256_lt(u256(0, 0), base_token_amount);
//         let (is_quote_amout_gt_zero) = uint256_lt(u256(0, 0), quote_token_amount);
//         assert is_base_amout_gt_zero + is_quote_amout_gt_zero = 2;  // base_amout > 0 && quote_amount > 0
//     }

//     ERC20._burn(this_pair_address, liquidity);
//     IERC20.transfer(base_token_address, to, base_token_amount);
//     IERC20.transfer(quote_token_address, to, quote_token_amount);

//     let (base_token_balance) = IERC20.balanceOf(base_token_address, this_pair_address);
//     let (quote_token_balance) = IERC20.balanceOf(quote_token_address, this_pair_address);

//     _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

//     let (sender) = get_caller_address();
//     ev_burn.emit(sender, base_token_amount, quote_token_amount, to);

//     if (fee_on == TRUE) {
//         _update_k_last(base_token_balance, quote_token_balance);
//         _unlock();
//         return (base_token_amount, quote_token_amount);
//     } else {
//         _unlock();
//         return (base_token_amount, quote_token_amount);
//     }
// }

// fn _transfer_out(
//     base_token_address: felt252,
//     quote_token_address: felt252,
//     base_amount_out: u256,
//     quote_amount_out: u256,
//     to: felt252,
// ) {
//     alloc_locals;
//     let (is_base_out_gt_zero) = uint256_lt(u256(0, 0), base_amount_out);
//     let (is_quote_out_gt_zero) = uint256_lt(u256(0, 0), quote_amount_out);

//     if (is_base_out_gt_zero == TRUE) {
//         IERC20.transfer(base_token_address, to, base_amount_out);
//         if (is_quote_out_gt_zero == TRUE) {
//             IERC20.transfer(quote_token_address, to, quote_amount_out);
//             return ();
//         }
//         return ();
//     } else {
//         if (is_quote_out_gt_zero == TRUE) {
//             IERC20.transfer(quote_token_address, to, quote_amount_out);
//             return ();
//         }
//         return ();
//     }
// }

 fn _lock() {
     let is_locked = sv_reentrancy_lock::read();
     assert(!is_locked, 'StarkswapV1: LOCKED');
     sv_reentrancy_lock::write(true);
 }

 fn _unlock() {
     let is_locked = sv_reentrancy_lock::read();
     assert(is_locked, 'StarkswapV1: UNLOCKED');
     sv_reentrancy_lock::write(false);
 }

// fn _invoke_callee(
//     base_amount_out: u256,
//     quote_amount_out: u256,
//     to: felt252,
//     calldata_len: felt252,
//     calldata: felt252*,
// ) {
//     let has_calldata = is_not_zero(calldata_len);
//     if (has_calldata == TRUE) {
//         let (caller_address) = get_caller_address();
//         IStarkswapV1Callee.starkswapV1Call(
//             to, caller_address, base_amount_out, quote_amount_out, calldata_len, calldata
//         );
//         return ();
//     }
//     return ();
// }

// fn _calc_input_amount(
//     reserve: u256, balance: u256, amount_out: u256
// ) -> (amount_in: u256) {
//     alloc_locals;
//     let (r0) = SafeUint256.sub_le(reserve, amount_out);

//     let (is_balance_gt_rt0) = uint256_lt(r0, balance);
//     if (is_balance_gt_rt0 == TRUE) {
//         let (r1) = SafeUint256.sub_le(balance, r0);
//         return (r1,);
//     } else {
//         return (u256(0, 0),);
//     }
// }

// fn _calc_balance_adjusted(
//     balance: u256, amount_in: u256
// ) -> (balance_adjusted: u256) {
//     alloc_locals;
//     let (r0) = SafeUint256.mul(balance, u256(1000, 0));
//     let (r1) = SafeUint256.mul(amount_in, u256(3, 0));

//     let (res) = SafeUint256.sub_le(r0, r1);
//     return (res,);
// }

// #[external]
// fn swap(
//     base_amount_out: u256,
//     quote_amount_out: u256,
//     to: felt252,
//     calldata_len: felt252,
//     calldata: felt252*,
// ) {
//     alloc_locals;
//     with_attr error_message("StarkswapV1: amount is not a valid u256") {
//         uint256_check(base_amount_out);
//         uint256_check(quote_amount_out);
//     }
//     _lock();
//     let (contract_address) = get_contract_address();

//     with_attr error_message("StarkswapV1: INSUFFICIENT_OUTPUT_AMOUNT") {
//         // require(base_amount_out > 0 || quote_amount_out > 0)
//         let (base_gt_zero) = uint256_lt(u256(0, 0), base_amount_out);
//         let (quote_gt_zero) = uint256_lt(u256(0, 0), quote_amount_out);
//         assert_not_zero(base_gt_zero + quote_gt_zero);
//     }

//     let (base_token_address) = sv_base_token_address::read();
//     let (base_token_reserve) = sv_base_token_reserve::read();

//     let (quote_token_address) = sv_quote_token_address::read();
//     let (quote_token_reserve) = sv_quote_token_reserve::read();

//     with_attr error_message("StarkswapV1: INSUFFICIENT_LIQUIDITY") {
//         // require(baseAmout < baseReserve && quoteAmount < quoteReserve)
//         let (p1) = uint256_lt(base_amount_out, base_token_reserve);
//         let (p2) = uint256_lt(quote_amount_out, quote_token_reserve);
//         assert p1 = 1;
//         assert p2 = 1;
//     }

//     with_attr error_message("StarkswapV1: INVALID_TO") {
//         assert_not_equal(to, base_token_address);
//         assert_not_equal(to, quote_token_address);
//     }

//     _transfer_out(base_token_address, quote_token_address, base_amount_out, quote_amount_out, to);
//     _invoke_callee(base_amount_out, quote_amount_out, to, calldata_len, calldata);

//     let (base_token_decimals) = IERC20.decimals(base_token_address);
//     let (quote_token_decimals) = IERC20.decimals(quote_token_address);

//     let (base_token_balance) = IERC20.balanceOf(base_token_address, contract_address);
//     let (quote_token_balance) = IERC20.balanceOf(quote_token_address, contract_address);

//     let (base_amount_in) = _calc_input_amount(
//         base_token_reserve, base_token_balance, base_amount_out
//     );
//     let (quote_amount_in) = _calc_input_amount(
//         quote_token_reserve, quote_token_balance, quote_amount_out
//     );

//     with_attr error_message("StarkswapV1: INSUFFICIENT_INPUT_AMOUNT") {
//         // require(base_amount_in > 0 || quote_amount_in > 0)
//         let (is_base_in_gt_0) = uint256_lt(u256(0, 0), base_amount_in);
//         let (is_quote_in_gt_0) = uint256_lt(u256(0, 0), quote_amount_in);

//         assert_not_zero(is_base_in_gt_0 + is_quote_in_gt_0);
//     }

//     let (base_token_balance_adjusted) = _calc_balance_adjusted(base_token_balance, base_amount_in);
//     let (quote_token_balance_adjusted) = _calc_balance_adjusted(
//         quote_token_balance, quote_amount_in
//     );

//     with_attr error_message("StarkswapV1: K") {
//         let (base_reserve_adjusted) = SafeUint256.mul(base_token_reserve, u256(1000, 0));
//         let (quote_reserve_adjusted) = SafeUint256.mul(quote_token_reserve, u256(1000, 0));

//         let (class_hash) = sv_curve::read();
//         let (a0, b0) = normalise_decimals(
//             base_token_balance_adjusted,
//             quote_token_balance_adjusted,
//             base_token_decimals,
//             quote_token_decimals,
//         );
//         let (a1, b1) = normalise_decimals(
//             base_reserve_adjusted, quote_reserve_adjusted, base_token_decimals, quote_token_decimals
//         );
//         let (new_k) = IStarkswapV1Curve.library_call_get_k(class_hash, a0, b0);
//         let (old_k) = IStarkswapV1Curve.library_call_get_k(class_hash, a1, b1);

//         assert_uint256_ge(new_k, old_k);
//     }

//     _update(base_token_balance, quote_token_balance, base_amount_out, quote_amount_out);
//     let (sender) = get_caller_address();
//     ev_swap.emit(sender, base_amount_in, quote_amount_in, base_amount_out, quote_amount_out, to);

//     _unlock();
//     return ();
// }

 fn normalise_decimals(reserve_a: u256, reserve_b: u256, decimals_a: u8, decimals_b: u8) -> (u256, u256) {
     let reserve_a_normalised = make_18_dec(reserve_a, decimals_a);
     let reserve_b_normalised = make_18_dec(reserve_b, decimals_b);

     return (reserve_a_normalised, reserve_b_normalised);
 }

 #[external]
 fn skim(to: ContractAddress) {
     _lock();
     let base_token_address = sv_base_token_address::read();
     let quote_token_address = sv_quote_token_address::read();
     let base_token_reserve = sv_base_token_reserve::read();
     let quote_token_reserve = sv_quote_token_reserve::read();

     let contract_address = get_contract_address();

     let base_token_balance = IERC20Dispatcher {contract_address: base_token_address}.balance_of(contract_address);
     let quote_token_balance = IERC20Dispatcher {contract_address: quote_token_address}.balance_of(contract_address);

     let base_token_amount = base_token_balance - base_token_reserve;
     let quote_token_amount = quote_token_balance - quote_token_reserve;

     IERC20Dispatcher {contract_address: base_token_address}.transfer(to, base_token_amount);
     IERC20Dispatcher {contract_address: quote_token_address}.transfer(to, quote_token_amount);

     _unlock();
 }

 #[external]
 fn sync() {
     _lock();
     let base_token_address = sv_base_token_address::read();
     let quote_token_address = sv_quote_token_address::read();
     let base_token_reserve = sv_base_token_reserve::read();
     let quote_token_reserve = sv_quote_token_reserve::read();

     let contract_address = get_contract_address();

     let base_token_balance = IERC20Dispatcher {contract_address: base_token_address}.balance_of(contract_address);
     let quote_token_balance = IERC20Dispatcher {contract_address: quote_token_address}.balance_of(contract_address);

     _update(base_token_balance, quote_token_balance, base_token_reserve, quote_token_reserve);

     _unlock();
 }

}
