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
    use integer::U256Add;
    use array::ArrayTrait;
    use array::OptionTrait;
    use starkswap_contracts::interfaces::IStarkswapV1Curve::IStarkswapV1Curve;
    use starkswap_contracts::interfaces::IStarkswapV1Factory::IStarkswapV1Factory;
    use starkswap_contracts::utils::decimals::make_18_dec;
    use starkswap_contracts::utils::decimals::unmake_18_dec;
    use starkswap_contracts::structs::route::Route;
    use starkswap_contracts::utils::sort::_sort_tokens;

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
        reserve_b: u256
    ) -> u256 {
        assert(amount_a > u256_from_felt252(0), 'INSUFFICIENT_AMOUNT');
        assert(reserve_a > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        assert(reserve_b > u256_from_felt252(0), 'INSUFFICIENT_LIQUIDITY');
        return  (amount_a * reserve_b) / reserve_a;
    }

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

    // #[view]
    // fn getAmountsOut(
    //     amount_in: u256, routes_len: felt252, routes: Array<Route>
    // ) -> (felt252, Array<u256>) {
    //
    // }
    //
    // #[view]
    // fn getAmountsIn(
    //     amount_out: u256, routes_len: felt252, routes: Array<Route>
    // ) -> (felt252, Array<u256>) {
    //
    // }
    //
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
    //
    // #[external]
    // fn removeLiquidity(
    //     token_a_address: felt252,
    //     token_b_address: felt252,
    //     curve: felt252,
    //     liquidity: u256,
    //     amount_a_min: u256,
    //     amount_b_min: u256,
    //     to: felt252,
    //     deadline: felt252,
    // ) -> (u256, u256) {
    // }
    //
    // #[external]
    // fn swapExactTokensForTokens(
    //     amount_in: u256,
    //     amount_out_min: u256,
    //     routes_len: felt252,
    //     routes: Array<Route>,
    //     to: felt252,
    //     deadline: felt252,
    // ) -> (felt252, Array<u256>) {
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
    //
    // }

    #[internal]
    fn _pair_for(
        token_a_address: ContractAddress,
        token_b_address: ContractAddress,
        curve: felt252
    ) -> felt252 {
        //TODO: Can this be replicated in cairo 1 or do we need to simply make a factory call?
        // let (base_address, quote_address) = _sort_tokens(token_a_address, token_b_address);
        // return calculate_contract_address(
        //     salt=0,
        //     class_hash=sv_pair_class_hash::read(),
        //     constructor_calldata_size=3,
        //     constructor_calldata=(base_address, quote_address, curve),
        //     deployer_address=sv_factory::read(),
        // );
        return 0;
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
}

//#[external]
//fn removeLiquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//token_a_address: felt,
//token_b_address: felt,
//curve: felt,
//liquidity: u256,
//amount_a_min: u256,
//amount_b_min: u256,
//to: felt,
//deadline: felt,
//) -> (amount_a: u256, amount_b: u256) {
//alloc_locals;

//_assert_valid_deadline(deadline);

//let (pair_address: felt) = _pair_for(token_a_address, token_b_address, curve);
//assert_not_zero(pair_address);

//let (caller_address: felt) = get_caller_address();

//IStarkswapV1Pair.transferFrom(
//contract_address=pair_address,
//sender=caller_address,
//recipient=pair_address,
//amount=liquidity,
//);
//let (amount_0: u256, amount_1: u256) = IStarkswapV1Pair.burn(
//contract_address=pair_address, to=to
//);
//let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address);

//let (local amount_a: u256, local amount_b: u256) = _sort_amounts(
//token_a_address, base_address, amount_0, amount_1
//);

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_A_AMOUNT") {
//let (is_amount_a_min_le_amount_a) = uint256_le(amount_a_min, amount_a);
//assert is_amount_a_min_le_amount_a = TRUE;
//}

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_B_AMOUNT") {
//let (is_amount_b_min_le_amount_b) = uint256_le(amount_b_min, amount_b);
//assert is_amount_b_min_le_amount_b = TRUE;
//}

//return (amount_a, amount_b);
//}

//fn _calculate_to_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//routes_len: felt, routes: Route*, to: felt
//) -> (to_address: felt) {
//if (routes_len == 0) {
//return (to_address=to);
//}

//let route = [routes + Route.SIZE];
//let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
//return (to_address=pair_address);
//}

//fn _swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amounts: u256*, routes_len: felt, routes: Route*, to: felt
//) -> () {
//alloc_locals;

//if (routes_len == 0) {
//return ();
//}

//let route = [routes];
//let (base_token: felt, _) = _sort_tokens(route.input, route.output);
//let (base_out: u256, quote_out: u256) = _sort_amounts(
//route.input, base_token, u256(0, 0), [amounts]
//);
//let (to_address: felt) = _calculate_to_address(routes_len - 1, routes, to);

//let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
//IStarkswapV1Pair.swap(
//contract_address=pair_address,
//base_out=base_out,
//quote_out=quote_out,
//to=to_address,
//calldata_len=0,
//calldata=cast(new (), felt*),
//);

//return _swap(amounts + u256.SIZE, routes_len - 1, routes + Route.SIZE, to);
//}

//#[external]
//fn swapExactTokensForTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amount_in: u256,
//amount_out_min: u256,
//routes_len: felt,
//routes: Route*,
//to: felt,
//deadline: felt,
//) -> (amounts_len: felt, amounts: u256*) {
//alloc_locals;

//_assert_valid_deadline(deadline);

//let (amounts_len: felt, amounts: u256*) = getAmountsOut(amount_in, routes_len, routes);

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT") {
//let (amount_out_min_le_return_amount) = uint256_le(
//amount_out_min, amounts[amounts_len - 1]
//);
//assert amount_out_min_le_return_amount = TRUE;
//}

//let route = [routes];
//let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
//let (caller_address: felt) = get_caller_address();
//IERC20.transferFrom(
//contract_address=route.input,
//sender=caller_address,
//recipient=pair_address,
//amount=[amounts],
//);
//_swap(amounts + u256.SIZE, routes_len, routes, to);

//return (amounts_len, amounts);
//}

//#[external]
//fn swapTokensForExactTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amount_out: u256,
//amount_in_max: u256,
//routes_len: felt,
//routes: Route*,
//to: felt,
//deadline: felt,
//) -> (amounts_len: felt, amounts: u256*) {
//alloc_locals;

//_assert_valid_deadline(deadline);

//let (amounts_len: felt, amounts: u256*) = getAmountsIn(amount_out, routes_len, routes);

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_INPUT_AMOUNT") {
//let (amount_in_le_input_amount_max) = uint256_le([amounts], amount_in_max);
//assert amount_in_le_input_amount_max = TRUE;
//}

//let route = [routes];
//let (pair_address: felt) = _pair_for(route.input, route.output, route.curve);
//let (caller_address: felt) = get_caller_address();
//IERC20.transferFrom(
//contract_address=route.input,
//sender=caller_address,
//recipient=pair_address,
//amount=[amounts],
//);
//_swap(amounts + u256.SIZE, routes_len, routes, to);

//return (amounts_len, amounts);
//}

//fn _in_out_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//pair_address: felt, token_in: felt
//) -> (in_token_address: felt, out_token_address: felt, is_input_base: felt) {
//let (base_token_address) = IStarkswapV1Pair.baseToken(pair_address);
//let (quote_token_address) = IStarkswapV1Pair.quoteToken(pair_address);

//if (token_in == base_token_address) {
//return (base_token_address, quote_token_address, TRUE);
//}

//if (token_in == quote_token_address) {
//return (quote_token_address, base_token_address, FALSE);
//}

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_INPUT_TOKEN") {
//assert_not_zero(1);
//}
//return (0, 0, FALSE);
//}

//fn _in_out_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//next_observation: Observation, current_observation: Observation, is_input_base: felt
//) -> (reserve_in: u256, reserve_out: u256) {
//alloc_locals;
//let (base_reserve) = SafeUint256.sub_le(
//next_observation.cumulative_base_reserve, current_observation.cumulative_base_reserve
//);
//let (quote_reserve) = SafeUint256.sub_le(
//next_observation.cumulative_quote_reserve, current_observation.cumulative_quote_reserve
//);

//if (is_input_base == TRUE) {
//return (base_reserve, quote_reserve);
//} else {
//return (quote_reserve, base_reserve);
//}
//}

//fn _sample_cumulative_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//observations_len: felt,
//observations: Observation*,
//is_input_base: felt,
//amount_in: u256,
//decimals_in: felt,
//decimals_out: felt,
//curve: felt,
//) -> (cumulative_price: u256) {
//alloc_locals;
//let continue = is_le(2, observations_len);
//if (continue == FALSE) {
//return (u256(0, 0),);
//}

//let current_observation: Observation = [observations];
//let next_observation: Observation = [observations + Observation.SIZE];

//let time_elapsed = next_observation.block_timestamp - current_observation.block_timestamp;
//let (reserve_in, reserve_out) = _in_out_reserves(
//next_observation, current_observation, is_input_base
//);

//let (amount_out) = getAmountOut(
//amount_in, reserve_in, reserve_out, decimals_in, decimals_out, curve
//);

//let (accumulator) = _sample_cumulative_price(
//observations_len - 1,
//observations + Observation.SIZE,
//is_input_base,
//amount_in,
//decimals_in,
//decimals_out,
//curve,
//);
//let (r) = SafeUint256.add(amount_out, accumulator);
//return (r,);
//}

//#[view]
//fn oracleQuote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//pair_address: felt, token_in: felt, amount_in: u256, sample_count: felt
//) -> (amount_out: u256) {
//alloc_locals;
//assert_le(1, sample_count);

//let (input_token_address, output_token_address, is_input_base) = _in_out_token(
//pair_address, token_in
//);
//let (observations_len, observations) = IStarkswapV1Pair.getObservations(
//pair_address, sample_count
//);

//let (curve: felt, _) = IStarkswapV1Pair.curve(pair_address);
//let (decimals_in: felt) = IERC20.decimals(input_token_address);
//let (decimals_out: felt) = IERC20.decimals(output_token_address);

//let (price_average_cumulative) = _sample_cumulative_price(
//observations_len, observations, is_input_base, amount_in, decimals_in, decimals_out, curve
//);
//let (quote, _) = SafeUint256.div_rem(price_average_cumulative, u256(sample_count, 0));

//return (quote,);
//}

//#[view]
//fn getAmountOut{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amount_in: u256,
//reserve_in: u256,
//reserve_out: u256,
//decimals_in: felt,
//decimals_out: felt,
//curve: felt,
//) -> (amount_out: u256) {
//alloc_locals;

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_INPUT_AMOUNT") {
//assert_uint256_gt(amount_in, u256(0, 0));
//}

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_LIQUIDITY") {
//assert_uint256_gt(reserve_in, u256(0, 0));
//assert_uint256_gt(reserve_out, u256(0, 0));
//}

//let (ai) = make_18_dec(amount_in, decimals_in);
//let (ri) = make_18_dec(reserve_in, decimals_in);
//let (ro) = make_18_dec(reserve_out, decimals_out);
//let (amount_out) = IStarkswapV1Curve.library_call_get_amount_out(curve, ai, ri, ro);

//let (ao) = unmake_18_dec(amount_out, decimals_out);
//return (ao,);
//}

//#[view]
//fn getAmountIn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amount_out: u256,
//reserve_in: u256,
//reserve_out: u256,
//decimals_in: felt,
//decimals_out: felt,
//curve: felt,
//) -> (amount_in: u256) {
//alloc_locals;

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT") {
//assert_uint256_gt(amount_out, u256(0, 0));
//}

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_LIQUIDITY") {
//assert_uint256_gt(reserve_in, u256(0, 0));
//assert_uint256_gt(reserve_out, u256(0, 0));
//}

//let (ao) = make_18_dec(amount_out, decimals_out);
//let (ri) = make_18_dec(reserve_in, decimals_in);
//let (ro) = make_18_dec(reserve_out, decimals_out);
//let (amount_in) = IStarkswapV1Curve.library_call_get_amount_in(curve, ao, ri, ro);

//let (ai) = unmake_18_dec(amount_in, decimals_in);
//return (ai,);
//}

//fn _calculate_amounts_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//routes_len: felt, routes: Route*, amounts: u256*
//) -> () {
//if (routes_len == 0) {
//return ();
//}

//let route = [routes];
//let (reserve_in: u256, reserve_out: u256) = _get_reserves(
//route.input, route.output, route.curve
//);
//let (decimals_in: felt) = IERC20.decimals(route.input);
//let (decimals_out: felt) = IERC20.decimals(route.output);

//let (amount_out: u256) = getAmountOut(
//[amounts], reserve_in, reserve_out, decimals_in, decimals_out, route.curve
//);
//let next_amounts = amounts + u256.SIZE;
//assert [next_amounts] = amount_out;

//return _calculate_amounts_out(routes_len - 1, routes + Route.SIZE, next_amounts);
//}

//#[view]
//fn getAmountsOut{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amount_in: u256, routes_len: felt, routes: Route*
//) -> (amounts_len: felt, amounts: u256*) {
//alloc_locals;

//with_attr error_message("StarkswapV1Router: INVALID_PATH") {
//let is_1_le_routes_len: felt = is_le(1, routes_len);
//assert is_1_le_routes_len = TRUE;
//}

//let amounts_len: felt = routes_len + 1;
//let (local amounts: u256*) = alloc();

//assert [amounts] = amount_in;
//_calculate_amounts_out(routes_len, routes, amounts);

//return (amounts_len, amounts);
//}

//fn _calculate_amounts_in{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//routes_len: felt, routes: Route*, amounts: u256*
//) -> () {
//if (routes_len == -1) {
//return ();
//}

//let route = routes[routes_len];
//let (reserve_in: u256, reserve_out: u256) = _get_reserves(
//route.input, route.output, route.curve
//);
//let (decimals_in: felt) = IERC20.decimals(route.input);
//let (decimals_out: felt) = IERC20.decimals(route.output);
//let (amount_in: u256) = getAmountIn(
//amounts[routes_len + 1], reserve_in, reserve_out, decimals_in, decimals_out, route.curve
//);
//assert amounts[routes_len] = amount_in;

//return _calculate_amounts_in(routes_len - 1, routes, amounts);
//}

//#[view]
//fn getAmountsIn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amount_out: u256, routes_len: felt, routes: Route*
//) -> (amounts_len: felt, amounts: u256*) {
//alloc_locals;

//with_attr error_message("StarkswapV1Router: INVALID_PATH") {
//let is_1_le_routes_len: felt = is_le(1, routes_len);
//assert is_1_le_routes_len = TRUE;
//}

//let amounts_len: felt = routes_len + 1;
//let (local amounts: u256*) = alloc();

//// let amounts = amounts + u256.SIZE * (amounts_len - 1)
//// let routes = routes + Route.SIZE * (routes_len - 1)

//assert amounts[amounts_len - 1] = amount_out;
//_calculate_amounts_in(routes_len - 1, routes, amounts);

//return (amounts_len, amounts);
//}


