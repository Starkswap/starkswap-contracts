import { expect } from 'chai';
import { starknet } from 'hardhat';
import {factoryFixture, pairFixture} from './shared/fixtures';
import {Account} from "@shardlabs/starknet-hardhat-plugin/dist/src/account";
import {PredeployedAccount} from '@shardlabs/starknet-hardhat-plugin/dist/src/devnet-utils';

describe('StarkswapV1Factory', function () {
    this.timeout(300_000);

    let setter: Account
    let account: Account

    before(async () => {
        const accounts: PredeployedAccount[] = await starknet.devnet.getPredeployedAccounts()

        setter = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            accounts[0].address,
            accounts[0].private_key
        )
        account  = await starknet.OpenZeppelinAccount.getAccountFromAddress(
            accounts[1].address,
            accounts[1].private_key
        )
    })

    it('fee_to, fee_to_setter, all_pairs_length', async () => {
        const fixture = await factoryFixture(setter)
        const factory = fixture.factory
        expect((await factory.call('fee_to')).address).to.eq(BigInt(0))
        expect((await factory.call('fee_to_setter')).address).to.eq(BigInt(setter.address))
        expect((await factory.call('all_pairs_length')).all_pairs_length).to.eq(BigInt(0))
    })

    async function createPair(reverse: boolean) {
        const fFixture = await factoryFixture(setter)
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
            expect(e.message).to.contain('StarkswapV1Factory: PAIR_EXISTS')
        }

        try {
            await setter.invoke(factory, 'create_pair', {
                token_a_address: quoteToken.address,
                token_b_address: baseToken.address,
                curve: volatileCurve
            });
        } catch (e: any) {
            expect(e.message).to.contain('StarkswapV1Factory: PAIR_EXISTS')
        }

        expect((await factory.call('get_pair', {
            token_a_address: baseToken.address,
            token_b_address: quoteToken.address,
            curve: volatileCurve
        })).pair_address).to.eq(BigInt(pair.address))

        expect((await factory.call('get_pair', {
            token_a_address: quoteToken.address,
            token_b_address: baseToken.address,
            curve: volatileCurve
        })).pair_address).to.eq(BigInt(pair.address))

        expect((await factory.call('all_pairs', {
            index: 0
        })).pair_address).to.eq(BigInt(pair.address))

        await setter.invoke(factory, 'create_pair', {
            token_a_address: baseToken.address,
            token_b_address: quoteToken.address,
            curve: stableCurve
        });

        const stable_pair_address = (await factory.call('get_pair', {
            token_a_address: baseToken.address,
            token_b_address: quoteToken.address,
            curve: stableCurve
        })).pair_address

        expect((await factory.call('all_pairs', {
            index: 1
        })).pair_address).to.eq(stable_pair_address)

        expect((await factory.call('all_pairs_length')).all_pairs_length).to.eq(BigInt(2))
        expect((await pair.call('factory')).address).to.eq(BigInt(factory.address))
        expect((await pair.call('base_token')).address).to.eq(BigInt(baseToken.address))
        expect((await pair.call('quote_token')).address).to.eq(BigInt(quoteToken.address))
        expect((await pair.call('curve')).curve_class_hash).to.eq(BigInt(volatileCurve))
    }

    it('create_pair', async () => {
        await createPair(false)
    })

    it('create_pair:reverse', async () => {
        await createPair(true)
    })

    it('set_fee_to', async () => {
        const fixture = await factoryFixture(setter)
        const factory = fixture.factory
        try {
            await account.invoke(factory, 'set_fee_to', {
                address: account.address
            });
        } catch (e: any) {
            expect(e.message).to.contain('StarkswapV1Factory: FORBIDDEN')
        }

        await setter.invoke(factory, 'set_fee_to', {
            address: account.address
        });
        expect((await factory.call('fee_to')).address).to.eq(BigInt(account.address))
    })

    it('set_fee_to_setter', async () => {
        const fixture = await factoryFixture(setter)
        const factory = fixture.factory
        try {
            await account.invoke(factory, 'set_fee_to_setter', {
                address: account.address
            });
        } catch (e: any) {
            expect(e.message).to.contain('StarkswapV1Factory: FORBIDDEN')
        }

        await setter.invoke(factory, 'set_fee_to_setter', {
            address: account.address
        });
        expect((await factory.call('feeToSetter')).address).to.eq(BigInt(account.address))

        try {
            await setter.invoke(factory, 'set_fee_to_setter', {
                address: setter.address
            });
        } catch (e: any) {
            expect(e.message).to.contain('StarkswapV1Factory: FORBIDDEN')
        }
    })

})
