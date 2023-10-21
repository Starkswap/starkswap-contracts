import {starknet} from "hardhat"
import {shortStringToBigIntUtil} from "@shardlabs/starknet-hardhat-plugin/dist/src/extend-utils"
import {StarknetContract, StarknetContractFactory} from "hardhat/types/runtime"
import {Account} from "@shardlabs/starknet-hardhat-plugin/dist/src/account"
import {expandTo18Decimals, orderBySize} from "./utils"

export const INITIAL_SUPPLY = 10000n

export interface FactoryFixture {
    factory: StarknetContract,
    pairClassHash: string,
    stableClassHash: string,
    volatileClassHash: string
}

export interface TokenFixture {
    tokenA: StarknetContract,
    tokenB: StarknetContract
}

export interface RouterFixture {
    router: StarknetContract
}

export interface PairFixture {
    factory: StarknetContract,
    baseToken: StarknetContract,
    quoteToken: StarknetContract,
    curve: string
    pair: StarknetContract
}

export async function tokenFixture(owner: Account): Promise<TokenFixture> {
    const erc20ContractFactory = await starknet.getContractFactory("openzeppelin_ERC20")
    await owner.declare(erc20ContractFactory);


    const tokenA = await owner.deploy(erc20ContractFactory, {
        name: shortStringToBigIntUtil("Token A"),
        symbol: shortStringToBigIntUtil("TKA"),
        initial_supply: expandTo18Decimals(INITIAL_SUPPLY),
        recipient: owner.address,
    })
    const tokenB = await owner.deploy(erc20ContractFactory, {
        name: shortStringToBigIntUtil("Token B"),
        symbol: shortStringToBigIntUtil("TKB"),
        initial_supply: expandTo18Decimals(INITIAL_SUPPLY),
        recipient: owner.address,
    })

    return {
        tokenA,
        tokenB
    }
}

export async function routerFixture(owner: Account, factoryFixture: FactoryFixture): Promise<RouterFixture> {
    const routerContractFactory: StarknetContractFactory = await starknet.getContractFactory("starkswap_contracts_StarkswapV1Router")
    console.log("declaring router")
    await owner.declare(routerContractFactory);
    console.log("deploying router")
    const routerContract = await owner.deploy(routerContractFactory, {
        factory_address: factoryFixture.factory.address,
        pair_class_hash: factoryFixture.pairClassHash,
    })
    console.log("deployed router")

    return {
        router: routerContract
    }

}

export async function factoryFixture(owner: Account): Promise<FactoryFixture> {
    const factoryContractFactory: StarknetContractFactory = await starknet.getContractFactory("starkswap_contracts_StarkswapV1Factory")
    const pairContractFactory: StarknetContractFactory = await starknet.getContractFactory("starkswap_contracts_StarkswapV1Pair")
    const stableContractFactory: StarknetContractFactory = await starknet.getContractFactory("starkswap_contracts_StarkswapV1Stable")
    const volatileContractFactory: StarknetContractFactory = await starknet.getContractFactory("starkswap_contracts_StarkswapV1Volatile")

    console.log("Declaring factory contracts")
    await owner.declare(pairContractFactory)
    await owner.declare(stableContractFactory)
    await owner.declare(volatileContractFactory)
    console.log("Declared factory contracts")

    const pairClassHash: string = await pairContractFactory.getClassHash();
    const stableClassHash: string = await stableContractFactory.getClassHash();
    const volatileClassHash: string = await volatileContractFactory.getClassHash();


    await owner.declare(factoryContractFactory)
    const factoryContract = await owner.deploy(factoryContractFactory, {
        fee_to_setter_address: owner.address,
        pair_class_hash: pairClassHash,
    })

    await owner.invoke(factoryContract, "add_curve", {
        curve_class_hash: stableClassHash,
    })

    await owner.invoke(factoryContract, "add_curve", {
        curve_class_hash: volatileClassHash,
    })

    return {
        factory: factoryContract,
        pairClassHash: pairClassHash,
        stableClassHash: stableClassHash,
        volatileClassHash: volatileClassHash
    }
}

export async function pairFixture(factoryFixture: FactoryFixture, owner: Account, reverse: boolean = false): Promise<PairFixture> {
    const pairContractFactory = await starknet.getContractFactory("starkswap_contracts_StarkswapV1Pair")
    const factory = factoryFixture.factory
    const tFixture = await tokenFixture(owner)
    const tokenA = tFixture.tokenA
    const tokenB = tFixture.tokenB

    let [a, b] = reverse ? [tokenB.address, tokenA.address] : [tokenA.address, tokenB.address]

    await owner.invoke(factory, "create_pair", {
        token_a_address: a,
        token_b_address: b,
        curve: factoryFixture.volatileClassHash
    })

    // @ts-ignore
    const res: bigint = await factory.call("get_pair", {
        token_a_address: tokenA.address,
        token_b_address: tokenB.address,
        curve: factoryFixture.volatileClassHash
    })

    const pair = pairContractFactory.getContractAt(`0x${res.toString(16)}`)
    const orderedTokens = orderBySize(tokenA, tokenB)

    return {
        factory: factory,
        baseToken: orderedTokens.base,
        quoteToken: orderedTokens.quote,
        curve: factoryFixture.volatileClassHash,
        pair: pair
    }
}
