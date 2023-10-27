import {expect} from 'chai';
import {starknet} from 'hardhat';
import {FactoryFixture, factoryFixture, pairFixture} from './shared/fixtures';
import {Account} from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import {PredeployedAccount} from '@shardlabs/starknet-hardhat-plugin/dist/src/devnet-utils';

describe('StarkswapV1Factory', function () {
    this.timeout(600_000);
    let dumpPath = "StarkswapV1Factory-dump.pkl";

    let setter: Account
    let account: Account
    let fFixture: FactoryFixture;

    before(async function (){
        await starknet.devnet.restart();

        const accounts: PredeployedAccount[] = await starknet.devnet.getPredeployedAccounts()

        setter = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            accounts[0].address,
            accounts[0].private_key
        )
        account  = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            accounts[1].address,
            accounts[1].private_key
        )

        fFixture = await factoryFixture(setter)
        await starknet.devnet.dump(dumpPath);
    });

    beforeEach(async function () {
        await starknet.devnet.restart();
        await starknet.devnet.load(dumpPath);
    });

    it('fee_to, fee_to_setter, all_pairs_length', async () => {
        const factory = fFixture.factory
        expect((await factory.call('fee_to_address'))).to.eq(BigInt(0))
        expect((await factory.call('fee_to_setter_address'))).to.eq(BigInt(setter.address))
        expect((await factory.call('all_pairs_length'))).to.eq(BigInt(0))
    })

    async function createPair(reverse: boolean) {
        const fixture = await pairFixture(fFixture, setter, reverse)
        const factory = fixture.factory
        const baseToken = fixture.baseToken
        const quoteToken = fixture.quoteToken
        const pair = fixture.pair
        const stableCurve = fFixture.stableClassHash
        const volatileCurve = fFixture.volatileClassHash

        try {
            await setter.invoke(factory, 'create_pair', {
                token_a_address: baseToken.address,
                token_b_address: quoteToken.address,
                curve: volatileCurve
            });
        } catch (e: any) {
            expect(e.message).to.contain(starknet.shortStringToBigInt('PAIR_EXISTS').toString(16))
        }

        try {
            await setter.invoke(factory, 'create_pair', {
                token_a_address: quoteToken.address,
                token_b_address: baseToken.address,
                curve: volatileCurve
            });
        } catch (e: any) {
            expect(e.message).to.contain(starknet.shortStringToBigInt('PAIR_EXISTS').toString(16))
        }

        expect((await factory.call('get_pair', {
            token_a_address: baseToken.address,
            token_b_address: quoteToken.address,
            curve: volatileCurve
        }))).to.eq(BigInt(pair.address))

        expect((await factory.call('get_pair', {
            token_a_address: quoteToken.address,
            token_b_address: baseToken.address,
            curve: volatileCurve
        }))).to.eq(BigInt(pair.address))

        expect((await factory.call('all_pairs', {
            index: 0
        }))).to.eq(BigInt(pair.address))

        await setter.invoke(factory, 'create_pair', {
            token_a_address: baseToken.address,
            token_b_address: quoteToken.address,
            curve: stableCurve
        });

        //@ts-ignore
        const stable_pair_address:string = (await factory.call('get_pair', {
            token_a_address: baseToken.address,
            token_b_address: quoteToken.address,
            curve: stableCurve
        }))

        expect((await factory.call('all_pairs', {
            index: 1
        }))).to.eq(stable_pair_address)

        expect(await factory.call('all_pairs_length')).to.eq(BigInt(2))
        expect(await pair.call('factory')).to.eq(BigInt(factory.address))
        expect(await pair.call('base_token')).to.eq(BigInt(baseToken.address))
        expect(await pair.call('quote_token')).to.eq(BigInt(quoteToken.address))
        // @ts-ignore
        expect((await pair.call(`curve`))[0]).to.eq(BigInt(volatileCurve))
    }

    it('create_pair', async () => {
        await createPair(false)
    })

    it('create_pair:reverse', async () => {
        await createPair(true)
    })

    it('set_fee_to', async () => {
        const factory = fFixture.factory
        try {
            await account.invoke(factory, 'set_fee_to_address', {
                address: account.address
            });
        } catch (e: any) {
            expect(e.message).to.contain(starknet.shortStringToBigInt('FORBIDDEN').toString(16))
        }

        await setter.invoke(factory, 'set_fee_to_address', {
            address: account.address
        });
        expect((await factory.call('fee_to_address'))).to.eq(BigInt(account.address))
    })

    it('set_fee_to_setter', async () => {
        const factory = fFixture.factory
        try {
            await account.invoke(factory, 'set_fee_to_setter_address', {
                address: account.address
            });
        } catch (e: any) {
            expect(e.message).to.contain(starknet.shortStringToBigInt('FORBIDDEN').toString(16))
        }

        await setter.invoke(factory, 'set_fee_to_setter_address', {
            address: account.address
        });
        expect((await factory.call('fee_to_setter_address'))).to.eq(BigInt(account.address))

        try {
            await setter.invoke(factory, 'set_fee_to_setter_address', {
                address: setter.address
            });
        } catch (e: any) {
            expect(e.message).to.contain(starknet.shortStringToBigInt('FORBIDDEN').toString(16))
        }
    })

})
