
* factory
    * pair indexing
    * pair creation
* pair
    * TWAP
        * https://docs.uniswap.org/protocol/V2/concepts/core-concepts/oracles
        * starkswap uses reserves instead of prices, why?
    * how is liquidity calculated?
    * what is the difference between reserve and balance?
        * balance = token.balanceOf(this)
        * reserve is the previously recorded balance
            * only done by _update()
    * what is k_last (`_update_k_last()`) ?
        * x * y = k
        * updated:
            * to 0 by `_mint_fee()` if `fee_to` is not set
            * to `x * y` by these funcs (via `_update_k_last()`) if `_mint_fee()` returns true (`fee_to` is set):
                * `mint()`
                * `burn()`
    * _mint_fee()
        * calculate new_k (according to params)
        * if new_k > old_k (and old_k != 0), mint some tokens to fee_to
            * `(total_supply * (root_k - root_k_last)) / (5 * root_k * root_k_last)` tokens minted
            * why this func?
        * called by:
            * `mint()`
            * `burn()`
    * burn()
        * pair-tokens are sent to contract ?
            * is this actually how it's done?
            * what prevents this from being MEV'ed?
            * why not do transfer_from() ?
        * burn() burns those tokens
        * and then sends the relative amount to `to` param
            * relative_amount = pair_token.balanceOf(this) * token.balanceOf(this) / pair_token.total_supply()
    * swap()
        * pair-tokens are sent to contract ?
            * like in `burn()`, see comments above
        * transfers `amount_out`'s (for both tokens)
        * `invoke_callee()`
        * ensures `amount_in` > `amount_out` (for either token)
        * `new_k = curve(base_token_balance, quote_token_balance)`
            * balances are adjust as such:
                * `adjust_balance = (token_balance * 1000) - (amount_in * 3)`
                * why this formula? doesn't make sense to me..
                * see `_calc_balance_adjusted()`
        * `old_k = curve(base_token_reserve, quote_token_reserve)`
        * assert new_k > old_k
            * why?
                * because they wanna ensure they're not losing money on it..
                * it means user deposited more than they should have
        * update reserves
    * mint()
        * pair-tokens are sent to contract ?
    * skim()
        * send `token_amount - token_reserve` to `to`
            * like in `burn()`, see comments above
        * amount to be minted is determined by `_calculate_liquidity()`
    * sync()
        * update reserves based on balances
* router
    * multi-swaps
    * `addLiquidity` / `removeLiquidity`
    * `oracleQuote`
* oracle (twap)
* how do fees work?




----------------------------


* possible angles of attack
    * problematic `_update()` func in StarkswapV1Pair.cairo
    * `_invoke_callee()`
        * all of the 5 funcs in pair don't have the `lock` modifier like their Uniswap equivalents:
            * `burn()`
            * `mint()`
            * `swap()`
            * `sync()`
            * `skim()`
    * places where y*x=k is assumed but could be stable curve as well
    * flash loan to fuck the Observations
    * understand how fees work
    * look into `getAmountsOut()` / `getAmountsIn()`
    * original uniswap code has overflow protections (using uint112), this code does not
    * original uniswap code has reentrancy guards (`lock` modifier), this code does not
