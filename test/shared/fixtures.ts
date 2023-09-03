import {starknet} from "hardhat"
import {shortStringToBigIntUtil} from "@shardlabs/starknet-hardhat-plugin/dist/src/extend-utils"
import {StarknetContract, StarknetContractFactory} from "hardhat/types/runtime"
import {Account} from "@shardlabs/starknet-hardhat-plugin/dist/src/account"
import {expandTo18Decimals, fromStringToHex, orderBySize, toUint256} from "./utils"

export const INITIAL_SUPPLY = 10000n

export interface FactoryFixture {
    factory: StarknetContract,
    pairClassHash: string,
    pairProxyClassHash: string,
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
    const erc20ContractFactory = await starknet.getContractFactory("../token-contract-artifacts/ERC20")
    await owner.declare(erc20ContractFactory);

    const tokenA = await owner.deploy(erc20ContractFactory, {
        name: shortStringToBigIntUtil("Token A"),
        symbol: shortStringToBigIntUtil("TKA"),
        decimals: 18,
        initial_supply: toUint256(expandTo18Decimals(INITIAL_SUPPLY)),
        recipient: owner.address,
        owner: owner.address
    })
    const tokenB = await owner.deploy(erc20ContractFactory, {
        name: shortStringToBigIntUtil("Token B"),
        symbol: shortStringToBigIntUtil("TKB"),
        decimals: 18,
        initial_supply: toUint256(expandTo18Decimals(INITIAL_SUPPLY)),
        recipient: owner.address,
        owner: owner.address
    })

    return {
        tokenA,
        tokenB
    }
}

export async function routerFixture(owner: Account, factoryFixture: FactoryFixture): Promise<RouterFixture> {
    const routerProxyContractFactory: StarknetContractFactory = await starknet.getContractFactory("RouterProxy")
    const routerContractFactory: StarknetContractFactory = await starknet.getContractFactory("StarkswapV1Router")
    const routerClassHash = await owner.declare(routerContractFactory);

    await owner.declare(routerProxyContractFactory);
    const routerProxyContract = await owner.deploy(routerProxyContractFactory, {
        implementation_hash: routerClassHash,
        factory_address: factoryFixture.factory.address,
        pair_proxy_class_hash: factoryFixture.pairProxyClassHash,
        pair_class_hash: factoryFixture.pairClassHash,
        proxy_admin: owner.address
    });
    routerProxyContract.setImplementation(routerContractFactory);

    return {
        router: routerProxyContract
    }

}

export async function factoryFixture(owner: Account): Promise<FactoryFixture> {
    const factoryProxyContractFactory: StarknetContractFactory = await starknet.getContractFactory("FactoryProxy")
    const factoryContractFactory: StarknetContractFactory = await starknet.getContractFactory("StarkswapV1Factory")
    const pairContractFactory: StarknetContractFactory = await starknet.getContractFactory("StarkswapV1Pair")
    const pairProxyContractFactory: StarknetContractFactory = await starknet.getContractFactory("PairProxy")
    const stableContractFactory: StarknetContractFactory = await starknet.getContractFactory("StarkswapV1Stable")
    const volatileContractFactory: StarknetContractFactory = await starknet.getContractFactory("StarkswapV1Volatile")
    const factoryClassHash = await owner.declare(factoryContractFactory)
    const pairProxyClassHash = await owner.declare(pairProxyContractFactory)
    const pairClassHash = await owner.declare(pairContractFactory)
    const stableClassHash = await owner.declare(stableContractFactory)
    const volatileClassHash = await owner.declare(volatileContractFactory)

    await owner.declare(factoryProxyContractFactory)
    const factoryProxyContract = await owner.deploy(factoryProxyContractFactory, {
        implementation_hash: factoryClassHash,
        pair_proxy_contract_class_hash: pairProxyClassHash,
        pair_contract_class_hash: pairClassHash,
        fee_to_setter: owner.address,
    })
    factoryProxyContract.setImplementation(factoryContractFactory);

    await owner.invoke(factoryProxyContract, "addCurve", {
        curve_class_hash: stableClassHash,
    })

    await owner.invoke(factoryProxyContract, "addCurve", {
        curve_class_hash: volatileClassHash,
    })

    return {
        factory: factoryProxyContract,
        pairClassHash: pairClassHash,
        pairProxyClassHash: pairProxyClassHash,
        stableClassHash: stableClassHash,
        volatileClassHash: volatileClassHash
    }
}

export async function pairFixture(factoryFixture: FactoryFixture, owner: Account, reverse: boolean=false): Promise<PairFixture> {
    const pairContractFactory = await starknet.getContractFactory("StarkswapV1Pair")
    const factory = factoryFixture.factory
    const tFixture = await tokenFixture(owner)
    const tokenA = tFixture.tokenA
    const tokenB = tFixture.tokenB

    let [a, b] = reverse ? [tokenB.address, tokenA.address] : [tokenA.address, tokenB.address]

    await owner.invoke(factory, "createPair", {
        token_a_address: a,
        token_b_address: b,
        curve: factoryFixture.volatileClassHash
    })

    const res = await factory.call("getPair", {
        token_a_address: tokenA.address,
        token_b_address: tokenB.address,
        curve: factoryFixture.volatileClassHash
    })

    const pairAddress = fromStringToHex(res.pair_address)

    const pair = pairContractFactory.getContractAt(pairAddress)

    const orderedTokens = orderBySize(tokenA, tokenB)

    return {
        factory: factory,
        baseToken: orderedTokens.base,
        quoteToken: orderedTokens.quote,
        curve: factoryFixture.volatileClassHash,
        pair: pair
    }
}
