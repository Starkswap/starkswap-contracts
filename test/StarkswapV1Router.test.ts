import { expect } from "chai";
import { starknet } from "hardhat";
import {
    FactoryFixture,
    factoryFixture,
    INITIAL_SUPPLY,
    RouterFixture,
    routerFixture, TokenFixture,
    tokenFixture
} from "./shared/fixtures";
import {expandTo18Decimals, fromStringToHex, toUint256} from "./shared/utils";
import {Account} from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import {StarknetContract} from "@shardlabs/starknet-hardhat-plugin/dist/src/types";
import {PredeployedAccount} from '@shardlabs/starknet-hardhat-plugin/dist/src/devnet-utils';

const TRANSFER_AMOUNT = 10000n
const SWAP_IN_AMOUNT = 1000n
const SWAP_OUT_AMOUNT = 906n

describe('StarkswapV1Router', function () {
    this.timeout(300_000);

    let setter: Account
    let fFixture: FactoryFixture
    let rFixture: RouterFixture
    let tFixture: TokenFixture

    async function addLiquidity(setter: Account, router: StarknetContract, tokenA: StarknetContract, tokenB: StarknetContract, curve: string) {

        await setter.invoke(tokenA, 'approve', {
            spender: router.address,
            amount: toUint256(TRANSFER_AMOUNT)
        })

        await setter.invoke(tokenB, 'approve', {
            spender: router.address,
            amount: toUint256(TRANSFER_AMOUNT)
        })

        await setter.invoke(router, 'addLiquidity', {
            token_a_address: tokenA.address,
            token_b_address: tokenB.address,
            curve: curve,
            amount_a_desired: toUint256(TRANSFER_AMOUNT),
            amount_b_desired: toUint256(TRANSFER_AMOUNT),
            amount_a_min: toUint256(0n),
            amount_b_min: toUint256(0n),
            to: setter.address,
            deadline: 99999999999999999999999n
        })
    }

    async function getPairFromFactory(factory: StarknetContract, tokenAAddress: string, tokenBAddress: string, curve: string): Promise<StarknetContract> {
        const pairContractFactory = await starknet.getContractFactory("StarkswapV1Pair")
        const res = await factory.call("getPair", {
            token_a_address: tokenAAddress,
            token_b_address: tokenBAddress,
            curve: curve
        })
        const pairAddress = fromStringToHex(res.pair_address)
        return pairContractFactory.getContractAt(pairAddress);
    }

    before(async () => {
        const accounts: PredeployedAccount[] = await starknet.devnet.getPredeployedAccounts()

        setter = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            accounts[0].address,
            accounts[0].private_key
        )
    })


    describe( 'quote,getAmountOut,getAmountIn', () => {

        before(async () => {
            fFixture = await factoryFixture(setter)
            rFixture = await routerFixture(setter, fFixture)
        })

        it('quote', async () => {
            const router = rFixture.router

            expect((await router.call('quote', {
                amount_a: toUint256(BigInt(1)),
                reserve_a: toUint256(BigInt(100)),
                reserve_b: toUint256(BigInt(200))
            })).amount_b).to.deep.eq(toUint256(BigInt(2)))

            expect((await router.call('quote', {
                amount_a: toUint256(BigInt(2)),
                reserve_a: toUint256(BigInt(200)),
                reserve_b: toUint256(BigInt(100))
            })).amount_b).to.deep.eq(toUint256(BigInt(1)))

            try {
                await router.call('quote', {
                    amount_a: toUint256(BigInt(0)),
                    reserve_a: toUint256(BigInt(100)),
                    reserve_b: toUint256(BigInt(200))
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_AMOUNT')
            }

            try {
                await router.call('quote', {
                    amount_a: toUint256(BigInt(1)),
                    reserve_a: toUint256(BigInt(0)),
                    reserve_b: toUint256(BigInt(200))
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_LIQUIDITY')
            }

            try {
                await router.call('quote', {
                    amount_a: toUint256(BigInt(1)),
                    reserve_a: toUint256(BigInt(100)),
                    reserve_b: toUint256(BigInt(0))
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_LIQUIDITY')
            }

        })

        it('getAmountOut', async () => {
            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash

            expect((await router.call('getAmountOut', {
                amount_in: toUint256(BigInt(2)),
                reserve_in: toUint256(BigInt(100)),
                reserve_out: toUint256(BigInt(100)),
                decimals_in: 18n,
                decimals_out: 18n,
                curve: volatileClassHash
            })).amount_out).to.deep.eq(toUint256(BigInt(1)))

            try {
                await router.call('getAmountOut', {
                    amount_in: toUint256(BigInt(0)),
                    reserve_in: toUint256(BigInt(100)),
                    reserve_out: toUint256(BigInt(100)),
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_INPUT_AMOUNT')
            }

            try {
                await router.call('getAmountOut', {
                    amount_in: toUint256(BigInt(2)),
                    reserve_in: toUint256(BigInt(0)),
                    reserve_out: toUint256(BigInt(100)),
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_LIQUIDITY')
            }

            try {
                await router.call('getAmountOut', {
                    amount_in: toUint256(BigInt(2)),
                    reserve_in: toUint256(BigInt(100)),
                    reserve_out: toUint256(BigInt(0)),
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_LIQUIDITY')
            }

        })

        it('getAmountIn', async () => {
            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash

            expect((await router.call('getAmountIn', {
                amount_out: toUint256(BigInt(1)),
                reserve_in: toUint256(BigInt(100)),
                reserve_out: toUint256(BigInt(100)),
                decimals_in: 18n,
                decimals_out: 18n,
                curve: volatileClassHash
            })).amount_in).to.deep.eq(toUint256(BigInt(2)))

            try {
                await router.call('getAmountIn', {
                    amount_out: toUint256(BigInt(0)),
                    reserve_in: toUint256(BigInt(100)),
                    reserve_out: toUint256(BigInt(100)),
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT')
            }

            try {
                await router.call('getAmountIn', {
                    amount_out: toUint256(BigInt(1)),
                    reserve_in: toUint256(BigInt(0)),
                    reserve_out: toUint256(BigInt(100)),
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_LIQUIDITY')
            }

            try {
                await router.call('getAmountIn', {
                    amount_out: toUint256(BigInt(1)),
                    reserve_in: toUint256(BigInt(100)),
                    reserve_out: toUint256(BigInt(0)),
                    decimals_in: 18n,
                    decimals_out: 18n,
                    curve: volatileClassHash
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INSUFFICIENT_LIQUIDITY')
            }

        })

    })

    describe( 'getAmountsOut,getAmountsIn', () => {

        before(async () => {
            fFixture = await factoryFixture(setter)
            rFixture = await routerFixture(setter, fFixture)
            tFixture = await tokenFixture(setter)
        })

        it('getAmountsOut', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            try {
                await router.call('getAmountsOut', {
                    amount_in: toUint256(2n),
                    routes: [
                        {input: tokenA.address, output: 0n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INVALID_PATH')
            }

            try {
                await router.call('getAmountsOut', {
                    amount_in: toUint256(2n),
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INVALID_PATH')
            }

            expect(await router.call('getAmountsOut', {
                amount_in: toUint256(2n),
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ]
            })).to.deep.eq({amounts_len: 2n, amounts: [toUint256(2n), toUint256(1n)]})

        })

        it('getAmountsIn', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            try {
                await router.call('getAmountsIn', {
                    amount_out: toUint256(2n),
                    routes: [
                        {input: tokenA.address, output: 0n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INVALID_PATH')
            }

            try {
                await router.call('getAmountsIn', {
                    amount_out: toUint256(2n),
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ]
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INVALID_PATH')
            }

            expect(await router.call('getAmountsIn', {
                amount_out: toUint256(1n),
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ]
            })).to.deep.eq({amounts_len: 2n, amounts: [toUint256(2n), toUint256(1n)]})

        })

    })

    describe( 'addLiquidity,removeLiquidity', () => {

        beforeEach(async () => {
            fFixture = await factoryFixture(setter)
            rFixture = await routerFixture(setter, fFixture)
            tFixture = await tokenFixture(setter)
        })

        it('addLiquidity', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB
            const factory = fFixture.factory

            let pair = await getPairFromFactory(factory, tokenA.address, tokenB.address, volatileClassHash)
            expect(pair.address).to.eq('0x0')

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)
            pair = await getPairFromFactory(factory, tokenA.address, tokenB.address, volatileClassHash)

            expect(await pair.call( 'balanceOf', {
                account: setter.address
            })).to.deep.eq({ balance: toUint256(9000n) })

            expect(await tokenA.call( 'balanceOf', {
                account: setter.address
            })).to.deep.eq({ balance: toUint256(expandTo18Decimals(INITIAL_SUPPLY) - 10000n) })

            expect(await tokenB.call( 'balanceOf', {
                account: setter.address
            })).to.deep.eq({ balance: toUint256(expandTo18Decimals(INITIAL_SUPPLY) - 10000n) })

        })

        it('removeLiquidity', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB
            const factory = fFixture.factory

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)
            let pair = await getPairFromFactory(factory, tokenA.address, tokenB.address, volatileClassHash)

            await setter.invoke(pair, 'approve', {
                spender: router.address,
                amount: toUint256(1000n)
            })

            await setter.invoke(router, 'removeLiquidity', {
                token_a_address: tokenA.address,
                token_b_address: tokenB.address,
                curve: volatileClassHash,
                liquidity: toUint256(1000n),
                amount_a_min: toUint256(0n),
                amount_b_min: toUint256(0n),
                to: setter.address,
                deadline: 99999999999999999999999n
            })

            const expectedAmount = expandTo18Decimals(INITIAL_SUPPLY) - TRANSFER_AMOUNT + SWAP_IN_AMOUNT
            expect(await tokenA.call( 'balanceOf', {
                account: setter.address
            })).to.deep.eq({ balance: toUint256(expectedAmount) })

            expect(await tokenB.call( 'balanceOf', {
                account: setter.address
            })).to.deep.eq({ balance: toUint256(expectedAmount) })

        })

    })

    describe( 'swap', () => {

        beforeEach(async () => {
            fFixture = await factoryFixture(setter)
            rFixture = await routerFixture(setter, fFixture)
            tFixture = await tokenFixture(setter)
        })

        it('swapExactTokensForTokens:volatile', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            await setter.invoke(tokenA, 'approve', {
                spender: router.address,
                amount: toUint256(SWAP_IN_AMOUNT)
            })

            try {
                await setter.invoke( router, 'swapExactTokensForTokens', {
                    amount_in: toUint256(SWAP_IN_AMOUNT),
                    amount_out_min: toUint256(SWAP_OUT_AMOUNT),
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ],
                    to: setter.address,
                    deadline: 99999999999999999999999n
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INVALID_PATH')
            }

            await setter.invoke( router, 'swapExactTokensForTokens', {
                amount_in: toUint256(SWAP_IN_AMOUNT),
                amount_out_min: toUint256(SWAP_OUT_AMOUNT),
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ],
                to: setter.address,
                deadline: 99999999999999999999999n
            })

            expect(await tokenB.call( 'balanceOf', {
                account: setter.address
            })).to.deep.eq({ balance: toUint256(expandTo18Decimals(INITIAL_SUPPLY) - TRANSFER_AMOUNT + SWAP_OUT_AMOUNT) })

        })

        it('swapTokensForExactTokens:volatile', async () => {

            const router = rFixture.router
            const volatileClassHash = fFixture.volatileClassHash
            const tokenA = tFixture.tokenA
            const tokenB = tFixture.tokenB

            await addLiquidity(setter, router, tokenA, tokenB, volatileClassHash)

            await setter.invoke(tokenA, 'approve', {
                spender: router.address,
                amount: toUint256(SWAP_IN_AMOUNT)
            })

            try {
                await setter.invoke( router, 'swapTokensForExactTokens', {
                    amount_out: toUint256(SWAP_OUT_AMOUNT),
                    amount_in_max: toUint256(SWAP_IN_AMOUNT),
                    routes: [
                        {input: tokenA.address, output: 1n, curve: volatileClassHash}
                    ],
                    to: setter.address,
                    deadline: 99999999999999999999999n
                })
            } catch (e: any) {
                expect(e.message).to.contain('StarkswapV1Router: INVALID_PATH')
            }

            await setter.invoke( router, 'swapTokensForExactTokens', {
                amount_out: toUint256(SWAP_OUT_AMOUNT),
                amount_in_max: toUint256(SWAP_IN_AMOUNT),
                routes: [
                    {input: tokenA.address, output: tokenB.address, curve: volatileClassHash}
                ],
                to: setter.address,
                deadline: 99999999999999999999999n
            })

            expect(await tokenB.call( 'balanceOf', {
                account: setter.address
            })).to.deep.eq({ balance: toUint256(expandTo18Decimals(INITIAL_SUPPLY) - TRANSFER_AMOUNT + SWAP_OUT_AMOUNT) })

        })
    })
})
