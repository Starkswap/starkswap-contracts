%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.structs.pair import Pair

@contract_interface
namespace IStarkswapV1Factory:

    func feeTo() -> (address: felt):
    end

    func pairClassHash() -> (pair_class_hash: felt):
    end

    func feeToSetter() -> (address: felt):
    end

    func getCurve(curve_class_hash: felt) -> (exists: felt):
    end

    func getPair(
       token_a_address: felt,
       token_b_address: felt,
       curve: felt
        ) -> (pair_address: felt):
    end

    func allPairs(
        index: felt
        ) -> (pair_address: felt):
    end

    func allPairsLength() -> (all_pairs_length: felt):
    end

    func getAllPairs() -> (pairs_len : felt, pairs : Pair*):
    end

    func createPair(
        token_a_address: felt,
        token_b_address: felt,
        curve: felt
        ) -> (pair_address: felt):
    end

    func setFeeTo(
        address: felt
        ) -> (address: felt):
    end

    func setFeeToSetter(
        address: felt
        ) -> (address: felt):
    end

    func setPairClassHash(
        pair_class_hash: felt
        ) -> (pair_class_hash: felt):
    end

    func addCurve(
        curve_class_hash: felt
        ) -> (exists: felt):
    end

end
