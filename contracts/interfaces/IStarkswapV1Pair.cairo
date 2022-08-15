%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStarkswapV1Pair:

    ########## ERC20 functions ##########

    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func decimals() -> (decimals: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt):
    end

    ########## END ERC20 functions ##########

    func MINIMUM_LIQUIDITY() -> (minimum: Uint256):
    end

    func factory() -> (address: felt):
    end

    func baseToken() -> (address: felt):
    end

    func quoteToken() -> (address: felt):
    end

    func curve() -> (curve_class_hash: felt, curve_name: felt):
    end

    func getReserves() -> (base_token_reserve: Uint256, quote_token_reserve: Uint256, block_timestamp_last: felt):
    end

    func baseCumulativeLast() -> (cumulative_last: Uint256):
    end

    func quoteCumulativeLast() -> (cumulative_last: Uint256):
    end

    func kLast() -> (k_last: Uint256):
    end

    func mint(to: felt) -> (liquidity: Uint256):
    end

    func burn(to: felt) -> (base_token_amount: Uint256, quote_token_amount: Uint256):
    end

    func swap(base_out: Uint256, quote_out: Uint256, to: felt, calldata_len: felt, calldata: felt*):
    end

    func skim(to: felt):
    end

    func sync():
    end

end
