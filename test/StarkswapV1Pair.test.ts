import {expect} from "chai";
import {starknet} from "hardhat";
import {factoryFixture, pairFixture} from "./shared/fixtures";
import {Account, OpenZeppelinAccount} from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import {StarknetContract} from "hardhat/types/runtime";
import {PredeployedAccount} from '@shardlabs/starknet-hardhat-plugin/dist/src/devnet-utils';
import {expandTo18Decimals, fromUint256, toUint256} from "./shared/utils";

const MINIMUM_LIQUIDITY = 10n ** 3n

describe("StarkswapV1Pair", function () {
    this.timeout(600_000);
    let wallet: Account;
    let factory: StarknetContract;
    let baseToken: StarknetContract;
    let quoteToken: StarknetContract;
    let pair: StarknetContract;
    let dumpPath = "dump.pkl"; //Path.join(tmpdir(), `devnet-dump-${new Date().getTime()}`);

    before(async function () {
        const accounts: PredeployedAccount[] = await starknet.devnet.getPredeployedAccounts()
        const wallet: OpenZeppelinAccount = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            accounts[0].address,
            accounts[0].private_key
        )

        const fFixture = await factoryFixture(wallet)
        //const fixture = await pairFixture(fFixture, wallet)
        //factory = fixture.factory;
        //baseToken = fixture.baseToken;
        //quoteToken = fixture.quoteToken;
        //pair = fixture.pair;

        await starknet.devnet.dump(dumpPath);
    });

    beforeEach(async function () {
        await starknet.devnet.restart();
        await starknet.devnet.load(dumpPath);
    });

    async function addLiquidity(baseTokenAmount: bigint, quoteTokenAmount: bigint) {
        await wallet.invoke(baseToken, "transfer", {recipient: pair.address, amount: toUint256(baseTokenAmount)})
        await wallet.invoke(quoteToken, "transfer", {recipient: pair.address, amount: toUint256(quoteTokenAmount)})
        await wallet.invoke(pair, "mint", {to: wallet.address})
    }

    it("mint", async function () {
    });

    //it("mint", async function () {
        //const baseTokenAmount = expandTo18Decimals(1n);
        //const quoteTokenAmount = expandTo18Decimals(4n);

        //await wallet.invoke(baseToken, "transfer", {
            //recipient: pair.address,
            //amount: toUint256(baseTokenAmount)
        //});
        //await wallet.invoke(quoteToken, "transfer", {
            //recipient: pair.address,
            //amount: toUint256(quoteTokenAmount)
        //});

        //const expectedLiquidity = expandTo18Decimals(2n);

        //let txHash = await wallet.invoke(pair, "mint", {
            //to: wallet.address
        //});

        //let receipt = await starknet.getTransactionReceipt(txHash)
        //let events = pair.decodeEvents(receipt.events)
        //expect(events).to.deep.equal([
            //{name: "Transfer", data: {from_: 0n, to: 42n, value: toUint256(MINIMUM_LIQUIDITY)}},
            //{name: "Transfer", data: {from_: 0n, to: BigInt(wallet.address), value: toUint256(expectedLiquidity - MINIMUM_LIQUIDITY)}},
            //{name: "ev_sync", data: {base_token_reserve: toUint256(baseTokenAmount), quote_token_reserve: toUint256(quoteTokenAmount)}},
            //{name: "ev_mint", data: {sender: BigInt(wallet.address), base_amount: toUint256(baseTokenAmount), quote_amount: toUint256(quoteTokenAmount)}}
        //])

        //expect(await pair.call("total_supply").then(res => fromUint256(res.totalSupply)))
            //.to.be.equal(expectedLiquidity)
        //expect(await pair.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance)))
            //.to.be.equal(expectedLiquidity - MINIMUM_LIQUIDITY)

        //const reserves = await pair.call("get_reserves")
        //expect(fromUint256(reserves.base_token_reserve)).to.be.equal(expandTo18Decimals(1n))
        //expect(fromUint256(reserves.quote_token_reserve)).to.be.equal(expandTo18Decimals(4n))
    //});


    //const swapTestCases: bigint[][] = [
        //[1, 5, 10, "1662497915624478906"],
        //[1, 10, 5, "453305446940074565"],

        //[2, 5, 10, "2851015155847869602"],
        //[2, 10, 5, "831248957812239453"],

        //[1, 10, 10, "906610893880149131"],
        //[1, 100, 100, "987158034397061298"],
        //[1, 1000, 1000, "996006981039903216"]
    //].map(a => a.map(n => (typeof n === 'string' ? BigInt(n) : expandTo18Decimals(BigInt(n)))))
    //swapTestCases.forEach((swapTestCase, i) => {
        //it(`get_input_price:${i}`, async () => {
            //const [swapAmount, baseTokenAmount, quoteTokenAmount, expectedOutputAmount] = swapTestCase
            //await addLiquidity(baseTokenAmount, quoteTokenAmount)
            //await wallet.invoke(baseToken, "transfer", {recipient: pair.address, amount: toUint256(swapAmount)})

            //try {
                //await wallet.invoke(pair, "swap", {
                    //base_amount_out: toUint256(0n),
                    //quote_amount_out: toUint256(expectedOutputAmount + 1n),
                    //to: wallet.address,
                    //calldata: []
                //})
            //} catch (err: any) {
                //expect(err.message).to.deep.contain("StarkswapV1: K");
            //}

            //await wallet.invoke(pair, "swap", {
                //base_amount_out: toUint256(0n),
                //quote_amount_out: toUint256(expectedOutputAmount),
                //to: wallet.address,
                //calldata: []
            //})
        //})
    //})

    //const optimisticTestCases: bigint[][] = [
        //['997000000000000000', 5, 10, 1], // given amountIn, amountOut = floor(amountIn * .997)
        //['997000000000000000', 10, 5, 1],
        //['997000000000000000', 5, 5, 1],
        //[1, 5, 5, '1003009027081243732'] // given amountOut, amountIn = ceiling(amountOut / .997)
    //].map(a => a.map(n => (typeof n === 'string' ? BigInt(n) : expandTo18Decimals(BigInt(n)))))
    //optimisticTestCases.forEach((optimisticTestCase, i) => {
        //it(`optimistic:${i}`, async () => {
            //const [outputAmount, baseTokenAmount, quoteTokenAmount, inputAmount] = optimisticTestCase
            //await addLiquidity(baseTokenAmount, quoteTokenAmount)
            //await wallet.invoke(baseToken, "transfer", {recipient: pair.address, amount: toUint256(inputAmount)})

            //try {
                //await wallet.invoke(pair, "swap", {
                    //base_amount_out: toUint256(outputAmount + 1n),
                    //quote_amount_out: toUint256(0n),
                    //to: wallet.address,
                    //calldata: []
                //})
            //} catch (err: any) {
                //expect(err.message).to.deep.contain("StarkswapV1: K");
            //}

            //await wallet.invoke(pair, "swap",{
                //base_amount_out: toUint256(outputAmount),
                //quote_amount_out: toUint256(0n),
                //to: wallet.address,
                //calldata: []
            //});
        //})
    //})

    //it('swap:baseToken', async () => {
        //const baseTokenAmount = expandTo18Decimals(5n)
        //const quoteTokenAmount = expandTo18Decimals(10n)
        //await addLiquidity(baseTokenAmount, quoteTokenAmount)

        //const swapAmount = expandTo18Decimals(1n)
        //const expectedOutputAmount = BigInt("1662497915624478906")
        //await wallet.invoke(baseToken, "transfer", {
            //recipient: pair.address,
            //amount: toUint256(swapAmount)
        //})

        //const txHash = await wallet.invoke(pair, "swap", {
            //base_amount_out: toUint256(0n),
            //quote_amount_out: toUint256(expectedOutputAmount),
            //to: wallet.address,
            //calldata: []
        //})

        //let receipt = await starknet.getTransactionReceipt(txHash)
        //let events = pair.decodeEvents(receipt.events)
        //expect(events).to.deep.equal([
            ////{name: "Transfer", data: {from_: BigInt(pair.address), to: BigInt(wallet.address), value: toUint256(expectedOutputAmount)}},
            //{name: "ev_sync", data: {base_token_reserve: toUint256(baseTokenAmount + swapAmount), quote_token_reserve: toUint256(quoteTokenAmount - expectedOutputAmount)}},
            //{name: "ev_swap", data: {
                    //sender: BigInt(wallet.address),
                    //base_token_amount_in: toUint256(swapAmount),
                    //quote_token_amount_in: toUint256(0n),
                    //base_token_amount_out: toUint256(0n),
                    //quote_token_amount_out: toUint256(expectedOutputAmount),
                    //to: BigInt(wallet.address)
                //}
            //}
        //]);

        //const reserves = await pair.call("get_reserves")
        //expect(fromUint256(reserves.base_token_reserve)).to.eq(baseTokenAmount + swapAmount)
        //expect(fromUint256(reserves.quote_token_reserve)).to.eq(quoteTokenAmount - expectedOutputAmount)

        //expect(await baseToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(baseTokenAmount + swapAmount)
        //expect(await quoteToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(quoteTokenAmount - expectedOutputAmount)
        //const totalSupplyBaseToken: bigint = await baseToken.call("total_supply").then(res => fromUint256(res.totalSupply))
        //const totalSupplyQuoteToken: bigint = await quoteToken.call("total_supply").then(res => fromUint256(res.totalSupply))
        //expect(await baseToken.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance))).to.eq(totalSupplyBaseToken - baseTokenAmount - swapAmount)
        //expect(await quoteToken.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance))).to.eq(totalSupplyQuoteToken - quoteTokenAmount + expectedOutputAmount)
    //})

    //it('swap:quote_token', async () => {
        //const baseTokenAmount = expandTo18Decimals(5n)
        //const quoteTokenAmount = expandTo18Decimals(10n)
        //await addLiquidity(baseTokenAmount, quoteTokenAmount)

        //const swapAmount = expandTo18Decimals(1n)
        //const expectedOutputAmount = BigInt("453305446940074565")
        //await wallet.invoke(quoteToken, "transfer", {
            //recipient: pair.address,
            //amount: toUint256(swapAmount)
        //})

        //const txHash = await wallet.invoke(pair, "swap", {
            //base_amount_out: toUint256(expectedOutputAmount),
            //quote_amount_out: toUint256(0n),
            //to: wallet.address,
            //calldata: []
        //})

        //let receipt = await starknet.getTransactionReceipt(txHash)
        //let events = pair.decodeEvents(receipt.events)
        //expect(events).to.deep.equal([
            ////{name: "Transfer", data: {from_: BigInt(pair.address), to: BigInt(wallet.address), value: toUint256(expectedOutputAmount)}},
            //{name: "ev_sync", data: {base_token_reserve: toUint256(baseTokenAmount - expectedOutputAmount), quote_token_reserve: toUint256(quoteTokenAmount + swapAmount)}},
            //{name: "ev_swap", data: {
                    //sender: BigInt(wallet.address),
                    //base_token_amount_in: toUint256(0n),
                    //quote_token_amount_in: toUint256(swapAmount),
                    //base_token_amount_out: toUint256(expectedOutputAmount),
                    //quote_token_amount_out: toUint256(0n),
                    //to: BigInt(wallet.address)
                //}
            //}
        //]);

        //const reserves = await pair.call("get_reserves")
        //expect(fromUint256(reserves.base_token_reserve)).to.eq(baseTokenAmount - expectedOutputAmount)
        //expect(fromUint256(reserves.quote_token_reserve)).to.eq(quoteTokenAmount + swapAmount)

        //expect(await baseToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(baseTokenAmount - expectedOutputAmount)
        //expect(await quoteToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(quoteTokenAmount + swapAmount)
        //const totalSupplyBaseToken: bigint = await baseToken.call("total_supply").then(res => fromUint256(res.totalSupply))
        //const totalSupplyQuoteToken: bigint = await quoteToken.call("total_supply").then(res => fromUint256(res.totalSupply))
        //expect(await baseToken.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance))).to.eq(totalSupplyBaseToken - baseTokenAmount + expectedOutputAmount)
        //expect(await quoteToken.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance))).to.eq(totalSupplyQuoteToken - quoteTokenAmount - swapAmount)
    //})

    //// Uni has a swap:gas test that validates some gas cost, not sure we want/need that
    //it('burn', async () => {
        //const baseTokenAmount = expandTo18Decimals(3n)
        //const quoteTokenAmount = expandTo18Decimals(3n)
        //await addLiquidity(baseTokenAmount, quoteTokenAmount)

        //const expectedLiquidity = expandTo18Decimals(3n)
        //await wallet.invoke(pair, "transfer", {
            //recipient: pair.address,
            //amount: toUint256(expectedLiquidity - MINIMUM_LIQUIDITY)
        //})

        //const txHash = await wallet.invoke(pair, "burn", {to: wallet.address})
        //let receipt = await starknet.getTransactionReceipt(txHash)
        //let events = pair.decodeEvents(receipt.events)
        //expect(events).to.deep.equal([
            //{name: "Transfer", data: {from_: BigInt(pair.address), to: BigInt(0), value: toUint256(expectedLiquidity - MINIMUM_LIQUIDITY)}},
            ////{name: "Transfer", data: {from_: BigInt(pair.address), to: BigInt(wallet.address), value: toUint256(baseTokenAmount - 1000n)}},
            ////{name: "Transfer", data: {from_: BigInt(pair.address), to: BigInt(wallet.address), value: toUint256(quoteTokenAmount - 1000n)}},
            //{name: "ev_sync", data: {base_token_reserve: toUint256(1000n), quote_token_reserve: toUint256(1000n)}},
            //{name: "ev_burn", data: {sender: BigInt(wallet.address), base_amount: toUint256(baseTokenAmount - 1000n), quote_amount: toUint256(quoteTokenAmount - 1000n), to: BigInt(wallet.address)}},

        //]);

        //expect(await pair.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance))).to.eq(0n)
        //expect(await pair.call("total_supply").then(res => fromUint256(res.totalSupply))).to.eq(MINIMUM_LIQUIDITY)
        //expect(await baseToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(1000n)
        //expect(await quoteToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(1000n)
        //const totalSupplyBaseToken: bigint = await baseToken.call("total_supply").then(res => fromUint256(res.totalSupply))
        //const totalSupplyQuoteToken: bigint = await quoteToken.call("total_supply").then(res => fromUint256(res.totalSupply))
        //expect(await baseToken.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance))).to.eq(totalSupplyBaseToken -1000n)
        //expect(await quoteToken.call("balance_of", {account: wallet.address}).then(res => fromUint256(res.balance))).to.eq(totalSupplyQuoteToken - 1000n)
    //})

    //// TODO: how do we mine a new block in starknet devnet?
    //// it('price{0,1}CumulativeLast', async () => {
    ////     const token0Amount = expandTo18Decimals(3n)
    ////     const token1Amount = expandTo18Decimals(3n)
    ////     await addLiquidity(token0Amount, token1Amount)
    ////
    ////     const blockTimestamp = await pair.call("getReserves").then(res => res.block_timestamp_last)
    ////     await mineBlock(provider, blockTimestamp + 1)
    ////     await pair.sync(overrides)
    ////
    ////     const initialPrice = encodePrice(token0Amount, token1Amount)
    ////     expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0])
    ////     expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1])
    ////     expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 1)
    ////
    ////     const swapAmount = expandTo18Decimals(3)
    ////     await token0.transfer(pair.address, swapAmount)
    ////     await mineBlock(provider, blockTimestamp + 10)
    ////     // swap to a new price eagerly instead of syncing
    ////     await pair.swap(0, expandTo18Decimals(1), wallet.address, '0x', overrides) // make the price nice
    ////
    ////     expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10))
    ////     expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10))
    ////     expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 10)
    ////
    ////     await mineBlock(provider, blockTimestamp + 20)
    ////     await pair.sync(overrides)
    ////
    ////     const newPrice = encodePrice(expandTo18Decimals(6), expandTo18Decimals(2))
    ////     expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10).add(newPrice[0].mul(10)))
    ////     expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10).add(newPrice[1].mul(10)))
    ////     expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 20)
    //// })

    //it('fee_to:off', async () => {
        //const baseTokenAmount = expandTo18Decimals(1000n)
        //const quoteTokenAmount = expandTo18Decimals(1000n)
        //await addLiquidity(baseTokenAmount, quoteTokenAmount)

        //const swapAmount = expandTo18Decimals(1n)
        //const expectedOutputAmount = BigInt("996006981039903216")
        //await wallet.invoke(quoteToken, "transfer", {recipient: pair.address, amount: toUint256(swapAmount)});
        //await wallet.invoke(pair, "swap", {
            //base_amount_out: toUint256(expectedOutputAmount),
            //quote_amount_out: toUint256(0n),
            //to: wallet.address,
            //calldata: []
        //})

        //const expectedLiquidity = expandTo18Decimals(1000n)
        //await wallet.invoke(pair, "transfer", {recipient: pair.address, amount: toUint256(expectedLiquidity - MINIMUM_LIQUIDITY)})
        //await wallet.invoke(pair, "burn", {to: wallet.address})
        //expect(await pair.call("total_supply").then(res => fromUint256(res.totalSupply))).to.eq(MINIMUM_LIQUIDITY)
    //})

    //it('fee_to:on', async () => {
        //const accounts: PredeployedAccount[] = await starknet.devnet.getPredeployedAccounts()
        //const other  = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            //accounts[2].address,
            //accounts[2].private_key
        //)
        //await wallet.invoke(factory, "set_fee_to", {address: other.address})

        //const baseTokenAmount = expandTo18Decimals(1000n)
        //const quoteTokenAmount = expandTo18Decimals(1000n)
        //await addLiquidity(baseTokenAmount, quoteTokenAmount)

        //const swapAmount = expandTo18Decimals(1n)
        //const expectedOutputAmount = BigInt('996006981039903216')
        //await wallet.invoke(quoteToken, "transfer", {recipient: pair.address, amount: toUint256(swapAmount)});
        //await wallet.invoke(pair, "swap", {
            //base_amount_out: toUint256(expectedOutputAmount),
            //quote_amount_out: toUint256(0n),
            //to: wallet.address,
            //calldata: []
        //})

        //const expectedLiquidity = expandTo18Decimals(1000n)
        //await wallet.invoke(pair, "transfer", {recipient: pair.address, amount: toUint256(expectedLiquidity - MINIMUM_LIQUIDITY)})
        //await wallet.invoke(pair, "burn", {to: wallet.address})

        //expect(await pair.call("total_supply").then(res => fromUint256(res.totalSupply))).to.eq(MINIMUM_LIQUIDITY + BigInt('249750499251388'))
        //expect(await pair.call("balance_of", {account: other.address}).then(res => fromUint256(res.balance))).to.eq(BigInt('249750499251388'))

        //// using 1000 here instead of the symbolic MINIMUM_LIQUIDITY because the amounts only happen to be equal...
        //// ...because the initial liquidity amounts were equal
        //expect(await baseToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(1000n + BigInt('249501683697445'))
        //expect(await quoteToken.call("balance_of", {account: pair.address}).then(res => fromUint256(res.balance))).to.eq(1000n + BigInt('250000187312969'))
    //})

});
