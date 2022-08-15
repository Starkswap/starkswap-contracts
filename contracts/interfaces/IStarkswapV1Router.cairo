%lang starknet

from starkware.cairo.common.uint256 import Uint256

from contracts.structs.route import Route

@contract_interface
namespace IStarkswapV1Router:

    func factory() -> (address: felt):
    end

    func addLiquidity(
        token_a_address: felt,
        token_b_address: felt,
        curve: felt,
        amount_a_desired: Uint256,
        amount_b_desired: Uint256,
        amount_a_min: Uint256,
        amount_b_min: Uint256,
        to: felt,
        deadline: felt
        ) -> (amount_a: Uint256, amount_b: Uint256, liquidity: Uint256):
    end

    func removeLiquidity(
        token_a_address: felt,
        token_b_address: felt,
        curve: felt,
        liquidity: Uint256,
        amount_a_min: Uint256,
        amount_b_min: Uint256,
        to: felt,
        deadline: felt
        ) -> (amount_a: Uint256, amount_b: Uint256):
    end

    func swapExactTokensForTokens(
         amount_in: Uint256,
         amount_out_min: Uint256,
         routes_len: felt,
         routes: Route*,
         to: felt,
         deadline: felt
         ) -> (amounts_len: felt, amounts: Uint256*):
    end

    func swapTokensForExactTokens(
         amount_out: Uint256,
         amount_in_max: Uint256,
         routes_len: felt,
         routes: Route*,
         to: felt,
         deadline: felt
         ) -> (amounts_len: felt, amounts: Uint256*):
    end

    #TODO: implement
    #func quote(
        #amount_a: Uint256,
        #reserve_a: Uint256,
        #reserve_b: Uint256,
        #curve: felt
        #) -> (amount_b: Uint256):
    #end

    func getAmountOut(
        amount_in: Uint256,
        reserve_in: Uint256,
        reserve_out: Uint256,
        curve: felt
        ) -> (amount_out: Uint256):
    end

    func getAmountIn(
        amount_out: Uint256,
        reserve_in: Uint256,
        reserve_out: Uint256,
        curve: felt
        ) -> (amount_in: Uint256):
    end

    func getAmountsOut(
        amount_in: Uint256,
        routes_len: felt,
        routes: Route*,
        ) -> (amounts_len: felt, amounts: Uint256*):
    end

    func getAmountsIn(
        amount_out: Uint256,
        routes_len: felt,
        routes: Route*,
        ) -> (amounts_len: felt, amounts: Uint256*):
    end

end
