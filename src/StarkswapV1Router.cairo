#[contract]
mod StarkswapV1Router {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use starknet::library_call_syscall;
    use starknet::contract_address_try_from_felt252;
    use starknet::contract_address_to_felt252;
    use starknet::class_hash_to_felt252;
    use starknet::call_contract_syscall;
    use starknet::get_block_timestamp;
    use zeroable::Zeroable;
    use integer::BoundedInt;
    use integer::u256_from_felt252;
    use integer::u128_to_felt252;
    use integer::u64_from_felt252;
    use array::ArrayTrait;
    use array::OptionTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1Curve;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1Factory;
    use starkswap_contracts::utils::decimals::make_18_dec;
    use starkswap_contracts::utils::decimals::unmake_18_dec;
    use starkswap_contracts::structs::route::Route;
    use starkswap_contracts::utils::sort::_sort_tokens;
    use starkswap_contracts::utils::sort::_sort_amounts;
    use starkswap_contracts::ierc20::IERC20;

    struct Storage {
        sv_factory_address: ContractAddress,
        sv_pair_class_hash: ClassHash,
    }

    #[constructor]
    fn constructor(
        factory_address: ContractAddress,
        pair_class_hash: ClassHash,
    ) {
        sv_factory_address::write(factory_address);
        sv_pair_class_hash::write(pair_class_hash);
    }

    #[view]
    fn factory() -> ContractAddress {
        return sv_factory_address::read();
    }

    #[view]
    fn pairClassHash() -> ClassHash { return sv_pair_class_hash::read(); }

    #[view]
    fn quote(
        amount_a: u256,
        reserve_a: u256,
        reserve_b: u256,
    ) -> u256 {
        assert(amount_a > u256_from_felt252(0), 'INSUFFICIENT_AMOUNT');
        assert(reserve_a > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        assert(reserve_b > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        return (amount_a * reserve_b) / reserve_a;
    }

    // #[view]
    // fn oracleQuote(
    //     pair_address: ContractAddress,
    //     token_in: ContractAddress,
    //     amount_in: u256,
    //     sample_count: felt252
    // ) -> u256 {
    //     assert_le(1, sample_count);
    //
    //     let (input_token_address, output_token_address, is_input_base) = _in_out_token(
    //     pair_address, token_in
    //     );
    //     let (observations_len, observations) = IStarkswapV1Pair.getObservations(
    //     pair_address, sample_count
    //     );
    //
    //     let (curve: felt, _) = IStarkswapV1Pair.curve(pair_address);
    //     let (decimals_in: felt) = IERC20.decimals(input_token_address);
    //     let (decimals_out: felt) = IERC20.decimals(output_token_address);
    //
    //     let (price_average_cumulative) = _sample_cumulative_price(
    //     observations_len, observations, is_input_base, amount_in, decimals_in, decimals_out, curve
    //     );
    //     let (quote, _) = SafeUint256.div_rem(price_average_cumulative, u256(sample_count, 0));
    //
    //     return (quote,);
    // }


    #[view]
    fn getAmountOut(amount_in: u256,
                    reserve_in: u256,
                    reserve_out: u256,
                    decimals_in: felt252,
                    decimals_out: felt252,
                    curve: ClassHash
    ) -> u256 {
        assert(amount_in > u256_from_felt252(0), 'INSUFFICIENT_INPUT_AMOUNT');
        assert(reserve_in > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        assert(reserve_out > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        let mut args = ArrayTrait::new();
        let ai = make_18_dec(amount_in, decimals_in);
        args.append(u128_to_felt252(ai.low));
        args.append(u128_to_felt252(ai.high));
        let ri = make_18_dec(reserve_in, decimals_in);
        args.append(u128_to_felt252(ri.low));
        args.append(u128_to_felt252(ri.high));
        let ro = make_18_dec(reserve_out, decimals_out);
        args.append(u128_to_felt252(ro.low));
        args.append(u128_to_felt252(ro.high));
        let res = library_call_syscall(curve, 'get_amount_out', args.span()).unwrap_syscall();
        // TODO: find out if u256 responses are packed into multiple felt252 for syscalls or if the below is sufficient
        let amount_out = u256_from_felt252(*res[0]);
        return unmake_18_dec(amount_out, decimals_out);
    }

    #[view]
    fn getAmountIn(amount_out: u256,
                   reserve_in: u256,
                   reserve_out: u256,
                   decimals_in: felt252,
                   decimals_out: felt252,
                   curve: ClassHash
    ) -> u256 {
        assert(amount_out > u256_from_felt252(0), 'INSUFFICIENT_OUTPUT_AMOUNT');
        assert(reserve_in > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        assert(reserve_out > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        let mut args = ArrayTrait::new();
        let ao = make_18_dec(amount_out, decimals_out);
        args.append(u128_to_felt252(ao.low));
        args.append(u128_to_felt252(ao.high));
        let ri = make_18_dec(reserve_in, decimals_in);
        args.append(u128_to_felt252(ri.low));
        args.append(u128_to_felt252(ri.high));
        let ro = make_18_dec(reserve_out, decimals_out);
        args.append(u128_to_felt252(ro.low));
        args.append(u128_to_felt252(ro.high));
        let res = library_call_syscall(curve, 'get_amount_in', args.span()).unwrap_syscall();
        // TODO: find out if u256 responses are packed into multiple felt252 for syscalls or if the below is sufficient
        return u256_from_felt252(*res[0]);
    }

    #[view]
    fn getAmountsOut(
        amount_in: u256,
        routes: Array<Route>
    ) -> Array<u256> {
        assert(routes.len() >= 1, 'INVALID_PATH');
        let mut amounts = ArrayTrait::new();
        amounts.append(amount_in);
        let mut counter = 0;
        loop {
            if counter == routes.len() {
                // TODO is this the correct break return val?
                break 0;
            }
            let route = *routes[counter];
            let (reserve_in, reserve_out) = _get_reserves(route.input, route.output, route.curve);
            let res_i = call_contract_syscall(route.input, 'decimals', ArrayTrait::new().span()).unwrap_syscall();
            let decimals_in = *res_i[0];
            let res_o = call_contract_syscall(route.output, 'decimals', ArrayTrait::new().span()).unwrap_syscall();
            let decimals_out = *res_o[0];
            let amount_out = getAmountOut(*amounts[counter], reserve_in, reserve_out, decimals_in, decimals_out, route.curve);
            amounts.append(amount_out);
            counter = counter + 1;
        };
        return amounts;
    }

    #[view]
    fn getAmountsIn(
        amount_out: u256,
        routes: Array<Route>
    ) -> Array<u256> {
        assert(routes.len() >= 1, 'INVALID_PATH');
        let mut amounts = ArrayTrait::new();
        amounts.append(amount_out);
        let mut counter = 0;
        loop {
            if counter == routes.len() {
                // TODO is this the correct break return val?
                break 0;
            }
            let route = *routes[counter];
            let (reserve_in, reserve_out) = _get_reserves(route.input, route.output, route.curve);
            let res_i = call_contract_syscall(route.input, 'decimals', ArrayTrait::new().span()).unwrap_syscall();
            let decimals_in = *res_i[0];
            let res_o = call_contract_syscall(route.output, 'decimals', ArrayTrait::new().span()).unwrap_syscall();
            let decimals_out = *res_o[0];
            let amount_in = getAmountIn(*amounts[counter], reserve_in, reserve_out, decimals_in, decimals_out, route.curve);
            amounts.append(amount_in);
            counter = counter + 1;
        };
        // TODO: more efficient way to do this than reverse array? revert to recursion?
        let mut rev_amounts = ArrayTrait::new();
        counter = amounts.len() - 1;
        loop {
            if counter < 0 {
                break 0;
            }
            rev_amounts.append(*amounts[counter]);
            counter = counter - 1;
        };
        return rev_amounts;
    }

    #[external]
    fn addLiquidity(
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: felt252,
    ) -> (u256, u256, u256) {
        _assert_valid_deadline(deadline);
        let (amount_a, amount_b, pair_address) = _add_liquidity(
            token_a_address,
            token_b_address,
            curve,
            amount_a_desired,
            amount_b_desired,
            amount_a_min,
            amount_b_min,
        );
        let caller_address = get_caller_address();
        let mut args_a = ArrayTrait::new();
        args_a.append(contract_address_to_felt252(caller_address));
        args_a.append(contract_address_to_felt252(pair_address));
        args_a.append(u128_to_felt252(amount_a.low));
        args_a.append(u128_to_felt252(amount_a.high));
        call_contract_syscall(token_a_address, 'transferFrom', args_a.span());
        let mut args_b = ArrayTrait::new();
        args_b.append(contract_address_to_felt252(caller_address));
        args_b.append(contract_address_to_felt252(pair_address));
        args_b.append(u128_to_felt252(amount_b.low));
        args_b.append(u128_to_felt252(amount_b.high));
        call_contract_syscall(token_b_address, 'transferFrom', args_b.span());
        let mut args_p = ArrayTrait::new();
        args_p.append(to);
        let res = call_contract_syscall(pair_address, 'mint', args_b.span()).unwrap_syscall();
        let liquidity = u256_from_felt252(*res[0]);
        return (amount_a, amount_b, liquidity);
    }

    #[external]
    fn removeLiquidity(
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash,
        liquidity: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: felt252,
    ) -> (u256, u256) {
        _assert_valid_deadline(deadline);
        let pair_address = _pair_for(token_a_address, token_b_address, curve);
        assert(!pair_address.is_zero(), 'NONEXISTENT_PAIR');
        let caller_address = get_caller_address();
        let mut args_p = ArrayTrait::new();
        args_p.append(contract_address_to_felt252(caller_address));
        args_p.append(contract_address_to_felt252(pair_address));
        args_p.append(u128_to_felt252(liquidity.low));
        args_p.append(u128_to_felt252(liquidity.high));
        call_contract_syscall(pair_address, 'transferFrom', args_p.span());
        let mut args_b = ArrayTrait::new();
        args_b.append(contract_address_to_felt252(to));
        let res = call_contract_syscall(pair_address, 'burn', args_b.span()).unwrap_syscall();
        let amount_0 = u256_from_felt252(*res[0]);
        let amount_1 = u256_from_felt252(*res[1]);
        let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
        let (amount_a, amount_b) = _sort_amounts(token_a_address, base_address, amount_0, amount_1);
        assert(amount_a_min <= amount_a, 'INSUFFICIENT_A_AMOUNT');
        assert(amount_b_min <= amount_b, 'INSUFFICIENT_B_AMOUNT');
        return (amount_a, amount_b);
    }

    // #[external]
    // fn swapExactTokensForTokens(
    //     amount_in: u256,
    //     amount_out_min: u256,
    //     routes_len: felt252,
    //     routes: Array<Route>,
    //     to: felt252,
    //     deadline: felt252,
    // ) -> (felt252, Array<u256>) {
    //     _assert_valid_deadline(deadline);
    //
    //     let (amounts_len: felt, amounts: u256*) = getAmountsOut(amount_in, routes_len, routes);
    //
    //     with_attr error_message("StarkswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT") {
    //     let (amount_out_min_le_return_amount) = uint256_le(
    //     amount_out_min, amounts[amounts_len - 1]
    //     );
    //     assert amount_out_min_le_return_amount = TRUE;
    //     }
    //
    //     let route = [routes];
    //     let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
    //     let (caller_address: felt) = get_caller_address();
    //     IERC20.transferFrom(
    //     contract_address=route.input,
    //     sender=caller_address,
    //     recipient=pair_address,
    //     amount=[amounts],
    //     );
    //     _swap(amounts + u256.SIZE, routes_len, routes, to);
    //
    //     return (amounts_len, amounts);
    //
    // }
    //
    // #[external]
    // fn swapTokensForExactTokens(
    //     amount_out: u256,
    //     amount_in_max: u256,
    //     routes_len: felt252,
    //     routes: Array<Route>,
    //     to: felt252,
    //     deadline: felt252,
    // ) -> (felt252, Array<u256>) {
    //     alloc_locals;
    //
    //     _assert_valid_deadline(deadline);
    //
    //     let (amounts_len: felt, amounts: u256*) = getAmountsIn(amount_out, routes_len, routes);
    //
    //     with_attr error_message("StarkswapV1Router: INSUFFICIENT_INPUT_AMOUNT") {
    //     let (amount_in_le_input_amount_max) = uint256_le([amounts], amount_in_max);
    //     assert amount_in_le_input_amount_max = TRUE;
    //     }
    //
    //     let route = [routes];
    //     let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
    //     let (caller_address: felt) = get_caller_address();
    //     IERC20.transferFrom(
    //     contract_address=route.input,
    //     sender=caller_address,
    //     recipient=pair_address,
    //     amount=[amounts],
    //     );
    //     _swap(amounts + u256.SIZE, routes_len, routes, to);
    //
    //     return (amounts_len, amounts);
    // }

    #[internal]
    fn _pair_for(
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash
    ) -> ContractAddress {
        //TODO: Can this be replicated in cairo 1 or do we need to simply make a factory call?
        // let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
        // return calculate_contract_address(
        //     salt=0,
        //     class_hash=sv_pair_class_hash::read(),
        //     constructor_calldata_size=3,
        //     constructor_calldata=(base_address, quote_address, curve),
        //     deployer_address=sv_factory::read(),
        // );
        return contract_address_try_from_felt252(0).unwrap();
    }

    #[internal]
    fn _get_reserves(
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash
    ) -> (u256, u256) {
        let mut args = ArrayTrait::new();
        args.append(contract_address_to_felt252(token_a_address));
        args.append(contract_address_to_felt252(token_b_address));
        args.append(class_hash_to_felt252(curve));
        let pair_response = call_contract_syscall(sv_factory_address::read(), 'getPair', args.span()).unwrap_syscall();
        let pair_address = contract_address_try_from_felt252(*pair_response[0]).unwrap();
        // assert(!pair_address.is_zero(), 'StarkswapV1Router: INVALID_PATH');
        let reserves_response = call_contract_syscall(pair_address, 'getReserves', ArrayTrait::new().span()).unwrap_syscall();
        let reserve_0 = u256_from_felt252(*reserves_response[0]);
        let reserve_1 = u256_from_felt252(*reserves_response[1]);
        let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
        if base_address == token_a_address {
            return (reserve_0, reserve_1);
        }
        return (reserve_1, reserve_0);
    }

    #[internal]
    fn _assert_valid_deadline(deadline: felt252) {
        let block_timestamp = get_block_timestamp();
        assert(block_timestamp < u64_from_felt252(deadline), 'EXPIRED');
    }

    fn _get_or_create_pair(
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash
    ) -> ContractAddress {
        let mut args = ArrayTrait::new();
        args.append(contract_address_to_felt252(token_a_address));
        args.append(contract_address_to_felt252(token_b_address));
        args.append(class_hash_to_felt252(curve));
        let get_pair_response = call_contract_syscall(sv_factory_address::read(), 'getPair', args.span()).unwrap_syscall();
        let pair_address = contract_address_try_from_felt252(*get_pair_response[0]).unwrap();
        if !pair_address.is_zero() {
            return pair_address;
        }
        let create_pair_response = call_contract_syscall(sv_factory_address::read(), 'createPair', args.span()).unwrap_syscall();
        let new_pair_address = contract_address_try_from_felt252(*create_pair_response[0]).unwrap();
        return new_pair_address;
    }

    #[internal]
    fn _add_liquidity(
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: ClassHash,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
    ) -> (u256, u256, ContractAddress) {
        let pair_address = _get_or_create_pair(token_a_address, token_b_address, curve);
        let (reserve_a, reserve_b) = _get_reserves(token_a_address, token_b_address, curve);
        if reserve_a + reserve_b == u256_from_felt252(0) {
            return (amount_a_desired, amount_b_desired, pair_address);
        }
        let amount_b_optimal = quote(amount_a_desired, reserve_a, reserve_b);
        if amount_b_optimal < amount_b_desired {
            assert(amount_b_min <= amount_b_optimal, 'INSUFFICIENT_B_AMOUNT');
            return (amount_a_desired, amount_b_optimal, pair_address);
        }
        let amount_a_optimal = quote(amount_b_desired, reserve_b, reserve_a);
        assert(amount_a_optimal <= amount_a_desired, 'INSUFFICIENT_A_AMOUNT');
        assert(amount_a_min <= amount_a_optimal, 'INSUFFICIENT_A_AMOUNT');
        return (amount_a_optimal, amount_b_desired, pair_address);
    }

    // #[internal]
    // fn _calculate_to_address(
    //     routes_len: felt,
    //     routes: Route*,
    //     to: felt
    // ) -> ContractAddress {
    //     if (routes_len == 0) {
    //     return (to_address=to);
    //     }
    //
    //     let route = [routes + Route.SIZE];
    //     let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
    //     return (to_address=pair_address);
    //     }
    //
    //     fn _swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    //     amounts: u256*, routes_len: felt, routes: Route*, to: felt
    //     ) -> () {
    //     alloc_locals;
    //
    //     if (routes_len == 0) {
    //     return ();
    //     }
    //
    //     let route = [routes];
    //     let (base_token: felt, _) = _sort_tokens(route.input, route.output);
    //     let (base_out: u256, quote_out: u256) = _sort_amounts(
    //     route.input, base_token, u256(0, 0), [amounts]
    //     );
    //     let (to_address: felt) = _calculate_to_address(routes_len - 1, routes, to);
    //
    //     let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
    //     IStarkswapV1Pair.swap(
    //     contract_address=pair_address,
    //     base_out=base_out,
    //     quote_out=quote_out,
    //     to=to_address,
    //     calldata_len=0,
    //     calldata=cast(new (), felt*),
    //     );
    //
    //     return _swap(amounts + u256.SIZE, routes_len - 1, routes + Route.SIZE, to);
    // }
    //
    // #[internal]
    // fn _in_out_token(
    //     pair_address: ContractAddress,
    //     token_in: felt
    // ) -> (ContractAddress, ContractAddress, bool) {
    //     let (base_token_address) = IStarkswapV1Pair.baseToken(pair_address);
    //     let (quote_token_address) = IStarkswapV1Pair.quoteToken(pair_address);
    //
    //     if (token_in == base_token_address) {
    //     return (base_token_address, quote_token_address, TRUE);
    //     }
    //
    //     if (token_in == quote_token_address) {
    //     return (quote_token_address, base_token_address, FALSE);
    //     }
    //
    //     with_attr error_message("StarkswapV1Router: INSUFFICIENT_INPUT_TOKEN") {
    //     assert_not_zero(1);
    //     }
    //     return (0, 0, FALSE);
    // }
    //
    // #[internal]
    // fn _sample_cumulative_price(
    //     observations_len: felt,
    //     observations: Observation*,
    //     is_input_base: felt,
    //     amount_in: u256,
    //     decimals_in: felt,
    //     decimals_out: felt,
    //     curve: felt,
    //     ) -> u256 {
    //     alloc_locals;
    //     let c = is_le(2, observations_len);
    //     if (c == FALSE) {
    //     return (u256(0, 0),);
    //     }
    //
    //     let current_observation: Observation = [observations];
    //     let next_observation: Observation = [observations + Observation.SIZE];
    //
    //     let time_elapsed = next_observation.block_timestamp - current_observation.block_timestamp;
    //     let (reserve_in, reserve_out) = _in_out_reserves(
    //     next_observation, current_observation, is_input_base
    //     );
    //
    //     let (amount_out) = getAmountOut(
    //     amount_in, reserve_in, reserve_out, decimals_in, decimals_out, curve
    //     );
    //
    //     let (accumulator) = _sample_cumulative_price(
    //     observations_len - 1,
    //     observations + Observation.SIZE,
    //     is_input_base,
    //     amount_in,
    //     decimals_in,
    //     decimals_out,
    //     curve,
    //     );
    //     let (r) = SafeUint256.add(amount_out, accumulator);
    //     return (r,);
    // }
}



