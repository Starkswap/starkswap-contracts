import {uint256ToBN, bnToUint256, Uint256} from "starknet/dist/utils/uint256";
import {StarknetContract} from "@shardlabs/starknet-hardhat-plugin/dist/src/types";

export function expandTo18Decimals(n: bigint): bigint {
    return n * 10n ** 18n
}

export function toUint256(n: bigint): {low: bigint, high: bigint} {
    let uint256 = bnToUint256(n.toString());

    return {
        low: BigInt(uint256.low.toString()),
        high: BigInt(uint256.high.toString())
    }
}

export function fromUint256(n: Uint256): bigint {
    return BigInt(uint256ToBN(n).toString())
}

export function fromStringToHex(str: string): string {
     return `0x${BigInt(str).toString(16)}`;
}

export function orderBySize(tokenA: StarknetContract, tokenB: StarknetContract): { base: StarknetContract, quote: StarknetContract }  {
    if (BigInt(tokenA.address) < BigInt(tokenB.address)) {
        return {
            base: tokenA,
            quote: tokenB
        }
    }
    return {
        base: tokenB,
        quote: tokenA
    }
}