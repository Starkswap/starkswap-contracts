import {expect} from "chai";
import {starknet} from "hardhat";
import {
    FactoryFixture,
    factoryFixture,
    INITIAL_SUPPLY,
    RouterFixture,
    routerFixture,
    TokenFixture,
    tokenFixture
} from "./shared/fixtures";
import {expandTo18Decimals} from "./shared/utils";
import {Account} from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import {StarknetContract} from "@shardlabs/starknet-hardhat-plugin/dist/src/types";
import {PredeployedAccount} from '@shardlabs/starknet-hardhat-plugin/dist/src/devnet-utils';
import {shortStringToBigIntUtil} from "@shardlabs/starknet-hardhat-plugin/dist/src/extend-utils";

const TRANSFER_AMOUNT = 10000n
const SWAP_IN_AMOUNT = 1000n
const SWAP_OUT_AMOUNT = 906n

describe('StarkswapV1Router', function () {
    this.timeout(600_000);

    let setter: Account
    let fFixture: FactoryFixture
    let rFixture: RouterFixture
    let tFixture: TokenFixture
    let dumpPath = "StarkswapV1Router-dump.pkl";


    async function addLiquidity(setter: Account, router: StarknetContract, tokenA: StarknetContract, tokenB: StarknetContract, curve: string) {

        await setter.invoke(tokenA, 'approve', {
            spender: router.address,
            amount: TRANSFER_AMOUNT
        })

        await setter.invoke(tokenB, 'approve', {
            spender: router.address,
            amount: TRANSFER_AMOUNT
        })

        await setter.invoke(router, 'add_liquidity', {
            token_a_address: tokenA.address,
            token_b_address: tokenB.address,
            curve: curve,
            amount_a_desired: TRANSFER_AMOUNT,
            amount_b_desired: TRANSFER_AMOUNT,
            amount_a_min: 0n,
            amount_b_min: 0n,
            to: setter.address,
            deadline: 99999999999999n
        })

    }

    async function getPairFromFactory(factory: StarknetContract, tokenAAddress: string, tokenBAddress: string, curve: string): Promise<StarknetContract> {
        const pairContractFactory = await starknet.getContractFactory("starkswap_contracts_StarkswapV1Pair")
        //@ts-ignore
        const pairAddress: bigint = await factory.call("get_pair", {
            token_a_address: tokenAAddress,
            token_b_address: tokenBAddress,
            curve: curve
        })

        return pairContractFactory.getContractAt(`0x${pairAddress.toString(16)}`);
    }

    before(async () => {
        await starknet.devnet.restart();

        const accounts: PredeployedAccount[] = await starknet.devnet.getPredeployedAccounts()

        setter = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            accounts[0].address,
            accounts[0].private_key
        )

        fFixture = await factoryFixture(setter)
        rFixture = await routerFixture(setter, fFixture)
        tFixture = await tokenFixture(setter)

        console.log(JSON.stringify({
            factoryAddress: fFixture.factory.address,
            pairClassHash: fFixture.pairClassHash,
            volatileClassHash: fFixture.volatileClassHash,
            stableClassHash: fFixture.stableClassHash,
            routerAddress: rFixture.router.address,
            tokenAAddress: tFixture.tokenA.address,
            tokenBAddress: tFixture.tokenB.address,
        }));

        await starknet.devnet.dump(dumpPath);

    })

    beforeEach(async function () {
        await starknet.devnet.restart();
        await starknet.devnet.load(dumpPath);
    });


    describe('quote,getAmountOut,getAmountIn', () => {


        it('quote', async () => {
            const router = rFixture.router

            expect(await router.call('quote', {
                amount_a: 1n,
                reserve_a: 100n,
                reserve_b: 200n
            })).to.deep.eq(2n)

            expect(await router.call('quote', {
                amount_a: 2n,
                reserve_a: 200n,
                reserve_b: 100n
            })).to.deep.eq(1n)

            try {
                await router.call('quote', {
                    amount_a: 0n,
                    reserve_a: 100n,
                    reserve_b: 200n
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_AMOUNT')).toString(16))
            }

            try {
                await router.call('quote', {
                    amount_a: 1n,
                    reserve_a: 0n,
                    reserve_b: 200n
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_LIQUIDITY')).toString(16))
            }

            try {
                await router.call('quote', {
                    amount_a: 1n,
                    reserve_a: 100n,
                    reserve_b: 0n
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_LIQUIDITY')).toString(16))
            }

        })

        it('get_amount_out', async () => {
            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash

            expect(await router.call('get_amount_out', {
                amount_in: 2n,
                reserve_in: 100n,
                reserve_out: 100n,
                decimals_in: 18n,
                decimals_out: 18n,
                curve: volatileClassHash
            })).to.deep.eq(1n)

            try {
                await router.call('get_amount_out', {
                    amount_in: 0n,
                    reserve_in: 100n,
                    reserve_out: 100n,
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_INPUT_AMOUNT')).toString(16))
            }

            try {
                await router.call('get_amount_out', {
                    amount_in: 2n,
                    reserve_in: 0n,
                    reserve_out: 100n,
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_LIQUIDITY')).toString(16))
            }

            try {
                await router.call('get_amount_out', {
                    amount_in: 2n,
                    reserve_in: 100n,
                    reserve_out: 0n,
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_LIQUIDITY')).toString(16))
            }

        })

        it('get_amount_in', async () => {
            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash

            expect(await router.call('get_amount_in', {
                amount_out: 1n,
                reserve_in: 100n,
                reserve_out: 100n,
                decimals_in: 18n,
                decimals_out: 18n,
                curve: volatileClassHash
            })).to.deep.eq(2n)

            try {
                await router.call('get_amount_in', {
                    amount_out: 0n,
                    reserve_in: 100n,
                    reserve_out: 100n,
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_OUTPUT_AMOUNT')).toString(16))
            }

            try {
                await router.call('get_amount_in', {
                    amount_out: 1n,
                    reserve_in: 0n,
                    reserve_out: 100n,
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_LIQUIDITY')).toString(16))
            }

            try {
                await router.call('get_amount_in', {
                    amount_out: 1n,
                    reserve_in: 100n,
                    reserve_out: 0n,
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INSUFFICIENT_LIQUIDITY')).toString(16))
            }

        })

    })

    describe('get_amounts_out,get_amounts_in', () => {


        it('get_amounts_out', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            try {
                await router.call('get_amounts_out', {
                    amount_in: 2n,
                    routes: [
                        {input: tokenA.address, output: 0n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INVALID_PATH')).toString(16))
            }

            try {
                await router.call('get_amounts_out', {
                    amount_in: 2n,
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INVALID_PATH')).toString(16))
            }

            expect(await router.call('get_amounts_out', {
                amount_in: 2n,
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ]
            })).to.deep.eq([2n, 1n])

        })

        it('get_amounts_in', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            try {
                await router.call('get_amounts_in', {
                    amount_out: 2n,
                    routes: [
                        {input: tokenA.address, output: 0n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INVALID_PATH')).toString(16))
            }

            try {
                await router.call('get_amounts_in', {
                    amount_out: 2n,
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INVALID_PATH')).toString(16))
            }

            expect(await router.call('get_amounts_in', {
                amount_out: 1n,
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ]
            })).to.deep.eq([2n, 1n])

        })

    })

    describe('add_liquidity,remove_liquidity', () => {

        it('add_liquidity', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB
            const factory = fFixture.factory

            let pair = await getPairFromFactory(factory, tokenA.address, tokenB.address, volatileClassHash)
            expect(pair.address).to.eq('0x0')

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)
            pair = await getPairFromFactory(factory, tokenA.address, tokenB.address, volatileClassHash)

            expect(await pair.call('balance_of', {
                account: setter.address
            })).to.deep.eq(9000n)

            expect(await tokenA.call('balance_of', {
                account: setter.address
            })).to.deep.eq(expandTo18Decimals(INITIAL_SUPPLY) - 10000n)

            expect(await tokenB.call('balance_of', {
                account: setter.address
            })).to.deep.eq(expandTo18Decimals(INITIAL_SUPPLY) - 10000n)
        })

        it('remove_liquidity', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB
            const factory = fFixture.factory

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)
            let pair = await getPairFromFactory(factory, tokenA.address, tokenB.address, volatileClassHash)

            await setter.invoke(pair, 'approve', {
                spender: router.address,
                amount: 1000n
            })

            await setter.invoke(router, 'remove_liquidity', {
                token_a_address: tokenA.address,
                token_b_address: tokenB.address,
                curve: volatileClassHash,
                liquidity: 1000n,
                amount_a_min: 0n,
                amount_b_min: 0n,
                to: setter.address,
                deadline: 99999999999999n
            })

            const expectedAmount = expandTo18Decimals(INITIAL_SUPPLY) - TRANSFER_AMOUNT + SWAP_IN_AMOUNT
            expect(await tokenA.call('balance_of', {
                account: setter.address
            })).to.deep.eq(expectedAmount)

            expect(await tokenB.call('balance_of', {
                account: setter.address
            })).to.deep.eq(expectedAmount)

        })

    })

    describe('swap', () => {

        it('swap_exact_tokens_for_tokens:volatile', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            await setter.invoke(tokenA, 'approve', {
                spender: router.address,
                amount: SWAP_IN_AMOUNT
            })

            try {
                await setter.invoke(router, 'swap_exact_tokens_for_tokens', {
                    amount_in: SWAP_IN_AMOUNT,
                    amount_out_min: SWAP_OUT_AMOUNT,
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ],
                    to: setter.address,
                    deadline: 99999999999999n
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INVALID_PATH')).toString(16))
            }

            await setter.invoke(router, 'swap_exact_tokens_for_tokens', {
                amount_in: SWAP_IN_AMOUNT,
                amount_out_min: SWAP_OUT_AMOUNT,
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ],
                to: setter.address,
                deadline: 99999999999999n
            })

            expect(await tokenB.call('balance_of', {
                account: setter.address
            })).to.deep.eq(expandTo18Decimals(INITIAL_SUPPLY) - TRANSFER_AMOUNT + SWAP_OUT_AMOUNT)

        })

        it('swap_tokens_for_exact_tokens:volatile', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            await setter.invoke(tokenA, 'approve', {
                spender: router.address,
                amount: SWAP_IN_AMOUNT
            })

            try {
                await setter.invoke(router, 'swap_tokens_for_exact_tokens', {
                    amount_out: SWAP_OUT_AMOUNT,
                    amount_in_max: SWAP_IN_AMOUNT,
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ],
                    to: setter.address,
                    deadline: 99999999999999n
                })
            } catch (e: any) {
                expect(e.message).to.contain(BigInt(shortStringToBigIntUtil('INVALID_PATH')).toString(16))
            }

            await setter.invoke(router, 'swap_tokens_for_exact_tokens', {
                amount_out: SWAP_OUT_AMOUNT,
                amount_in_max: SWAP_IN_AMOUNT,
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ],
                to: setter.address,
                deadline: 99999999999999n
            })

            expect(await tokenB.call('balance_of', {
                account: setter.address
            })).to.deep.eq(expandTo18Decimals(INITIAL_SUPPLY) - TRANSFER_AMOUNT + SWAP_OUT_AMOUNT)

        })
    })
})
