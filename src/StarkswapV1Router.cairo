//%builtins pedersen range_check ecdsa

//u256,
//uint256_le,
//uint256_eq
//)

////####################################################################
//// Storage
////####################################################################

//@storage_var
//fn sv_factory() -> (address: felt) {
//}

//@storage_var
//fn sv_pair_class_hash() -> (pair_class_hash: felt) {
//}

////####################################################################
//// Constructor
////####################################################################

//#[constructor]
//fn constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//factory_address: felt, pair_class_hash: felt
//) {
//assert_not_zero(factory_address);
//sv_factory.write(factory_address);

//assert_not_zero(pair_class_hash);
//sv_pair_class_hash.write(pair_class_hash);

//return ();
//}

////####################################################################
//// View functions
////####################################################################

//#[view]
//fn factory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt) {
//return sv_factory.read();
//}

//#[view]
//fn pairClassHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
//pair_class_hash: felt
//) {
//return sv_pair_class_hash.read();
//}

////####################################################################
//// External functions
////####################################################################

//fn _pair_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//token_a_address: felt, token_b_address: felt, curve: felt
//) -> (pair_address: felt) {
//alloc_locals;

//let (factory_address: felt) = sv_factory.read();
//let (pair_class_hash: felt) = sv_pair_class_hash.read();

//let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address);
//let (pair_address: felt) = get_contract_address{hash_ptr=pedersen_ptr}(
//salt=0,
//class_hash=pair_class_hash,
//constructor_calldata_size=3,
//constructor_calldata=cast(new (base_address, quote_address, curve), felt*),
//deployer_address=factory_address,
//);

//return (pair_address=pair_address);
//}

//fn _get_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//token_a_address: felt, token_b_address: felt, curve: felt
//) -> (reserve_a: u256, reserve_b: u256) {
//alloc_locals;

//let (factory_address: felt) = sv_factory.read();
//let (local pair_address: felt) = IStarkswapV1Factory.getPair(
//factory_address, token_a_address, token_b_address, curve
//);
//with_attr error_message("StarkswapV1Router: INVALID_PATH") {
//assert_not_zero(pair_address);
//}
//let (
//reserve_0: u256, reserve_1: u256, block_timestamp_last: felt
//) = IStarkswapV1Pair.getReserves(contract_address=pair_address);
//let (base_address: felt, quote_address: felt) = _sort_tokens(token_a_address, token_b_address);

//if (base_address == token_a_address) {
//return (reserve_0, reserve_1);
//}

//return (reserve_1, reserve_0);
//}

//fn _assert_valid_deadline{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//deadline: felt
//) -> () {
//let (block_timestamp) = get_block_timestamp();
//with_attr error_message("StarkswapV1Router: EXPIRED") {
//assert_le(block_timestamp, deadline);
//}

//return ();
//}

//fn _get_or_create_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//token_a_address: felt, token_b_address: felt, curve: felt
//) -> (address: felt) {
//let (factory_address: felt) = sv_factory.read();
//let (existing_pair_address: felt) = IStarkswapV1Factory.getPair(
//factory_address, token_a_address, token_b_address, curve
//);
//if (existing_pair_address == FALSE) {
//let (new_pair_address: felt) = IStarkswapV1Factory.createPair(
//factory_address, token_a_address, token_b_address, curve
//);
//assert_not_zero(new_pair_address);
//return (address=new_pair_address);
//}

//return (address=existing_pair_address);
//}

//fn _add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//token_a_address: felt,
//token_b_address: felt,
//curve: felt,
//amount_a_desired: u256,
//amount_b_desired: u256,
//amount_a_min: u256,
//amount_b_min: u256,
//) -> (amount_a: u256, amount_b: u256, pair_address: felt) {
//alloc_locals;

//let (local pair_address: felt) = _get_or_create_pair(token_a_address, token_b_address, curve);
//let (reserve_a: u256, reserve_b: u256) = _get_reserves(
//token_a_address, token_b_address, curve
//);

//let (sum: u256) = SafeUint256.add(reserve_a, reserve_b);
//let (is_sum_zero: felt) = uint256_eq(sum, u256(0, 0));
//if (is_sum_zero == TRUE) {
//return (amount_a_desired, amount_b_desired, pair_address);
//}

//let (amount_b_optimal: u256) = quote(amount_a_desired, reserve_a, reserve_b);
//let (is_b_optimal_le_b_desired) = uint256_le(amount_b_optimal, amount_b_desired);
//if (is_b_optimal_le_b_desired == TRUE) {
//with_attr error_message("StarkswapV1Router: INSUFFICIENT_B_AMOUNT") {
//let (b_min_le_b_optimal) = uint256_le(amount_b_min, amount_b_optimal);
//assert b_min_le_b_optimal = TRUE;
//}
//return (amount_a_desired, amount_b_optimal, pair_address);
//}

//let (amount_a_optimal: u256) = quote(amount_b_desired, reserve_b, reserve_a);
//let (is_a_optimal_le_a_desired) = uint256_le(amount_a_optimal, amount_a_desired);
//assert is_a_optimal_le_a_desired = TRUE;
//with_attr error_message("StarkswapV1Router: INSUFFICIENT_A_AMOUNT") {
//let (is_a_min_le_a_optimal) = uint256_le(amount_a_min, amount_a_optimal);
//assert is_a_min_le_a_optimal = TRUE;
//return (amount_a_optimal, amount_b_desired, pair_address);
//}
//}

//#[external]
//fn addLiquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//token_a_address: felt,
//token_b_address: felt,
//curve: felt,
//amount_a_desired: u256,
//amount_b_desired: u256,
//amount_a_min: u256,
//amount_b_min: u256,
//to: felt,
//deadline: felt,
//) -> (amount_a: u256, amount_b: u256, liquidity: u256) {
//_assert_valid_deadline(deadline);

//let (amount_a: u256, amount_b: u256, pair_address: felt) = _add_liquidity(
//token_a_address,
//token_b_address,
//curve,
//amount_a_desired,
//amount_b_desired,
//amount_a_min,
//amount_b_min,
//);

//let (caller_address: felt) = get_caller_address();

//IERC20.transferFrom(
//contract_address=token_a_address,
//sender=caller_address,
//recipient=pair_address,
//amount=amount_a,
//);
//IERC20.transferFrom(
//contract_address=token_b_address,
//sender=caller_address,
//recipient=pair_address,
//amount=amount_b,
//);
//let (liquidity: u256) = IStarkswapV1Pair.mint(contract_address=pair_address, to=to);

//return (amount_a, amount_b, liquidity);
//}

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

//#[view]
//fn quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//amount_a: u256, reserve_a: u256, reserve_b: u256
//) -> (amount_b: u256) {
//alloc_locals;

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_AMOUNT") {
//assert_uint256_gt(amount_a, u256(0, 0));
//}

//with_attr error_message("StarkswapV1Router: INSUFFICIENT_LIQUIDITY") {
//assert_uint256_gt(reserve_a, u256(0, 0));
//assert_uint256_gt(reserve_b, u256(0, 0));
//}

//let (r0) = SafeUint256.mul(amount_a, reserve_b);
//let (amount_b, _) = SafeUint256.div_rem(r0, reserve_a);

//return (amount_b,);
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


