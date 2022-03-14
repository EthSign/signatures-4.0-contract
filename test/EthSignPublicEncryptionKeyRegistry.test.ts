// Start - Support direct Mocha run & debug
import 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
import {deployContract, signer} from './framework/contracts'
import {EthSignPublicEncryptionKeyRegistry} from '../typechain'
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers'
import {ethers} from 'ethers'

chai.use(solidity)

function getRandomString(): string {
    let outString = ''
    const inOptions = 'abcdefghijklmnopqrstuvwxyz0123456789'
    for (let i = 0; i < 32; i++) {
        outString += inOptions.charAt(
            Math.floor(Math.random() * inOptions.length)
        )
    }
    return outString
}

describe('EthSignPublicEncryptionKeyRegistry', () => {
    let contract: EthSignPublicEncryptionKeyRegistry
    let s0: SignerWithAddress, s1: SignerWithAddress

    before(async () => {
        s0 = await signer(0)
        s1 = await signer(1)
        contract = await deployContract<EthSignPublicEncryptionKeyRegistry>(
            'EthSignPublicEncryptionKeyRegistry',
            ethers.constants.AddressZero
        )
    })

    describe('Basic tests', () => {
        it("should correctly record a user's public encryption key", async () => {
            const s0Key = getRandomString()
            const s1Key = getRandomString()
            const txS0 = await contract.connect(s0).register(s0Key)
            void expect(txS0)
                .to.emit(contract, 'Registered')
                .withArgs(s0.address, s0Key)
            const txS1 = await contract.connect(s1).register(s1Key)
            void expect(txS1)
                .to.emit(contract, 'Registered')
                .withArgs(s1.address, s1Key)
            const s0KeyFromContract = await contract.getKey(s0.address)
            expect(s0KeyFromContract).to.equal(s0Key)
            const s1KeyFromContract = await contract.getKey(s1.address)
            expect(s1KeyFromContract).to.equal(s1Key)
        })
    })
})
