%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.structs.pair import Pair
from contracts.structs.balance import Balance

@contract_interface
namespace IStarkswapV1Factory {
    func feeTo() -> (address: felt) {
    }

    func pairClassHash() -> (pair_class_hash: felt) {
    }

    func feeToSetter() -> (address: felt) {
    }

    func getCurve(curve_class_hash: felt) -> (exists: felt) {
    }

    func getPair(token_a_address: felt, token_b_address: felt, curve: felt) -> (pair_address: felt) {
    }

    func allPairs(index: felt) -> (pair_address: felt) {
    }

    func allPairsLength() -> (all_pairs_length: felt) {
    }

    func getAllPairs() -> (pairs_len: felt, pairs: Pair*) {
    }

    func createPair(token_a_address: felt, token_b_address: felt, curve: felt) -> (pair_address: felt) {
    }

    func setFeeTo(address: felt) -> (address: felt) {
    }

    func setFeeToSetter(address: felt) -> (address: felt) {
    }

    func setPairClassHash(pair_class_hash: felt) -> (pair_class_hash: felt) {
    }

    func addCurve(curve_class_hash: felt) -> (exists: felt) {
    }

    func getBalances(account: felt) -> (balances_len: felt, balances: Balance*) {
    }
}
