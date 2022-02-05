// Start - Support direct Mocha run & debug
import 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
import {deployContractWithProxy, signer} from './framework/contracts'
import {EthSignV4} from '../typechain'
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers'
import {successfulTransaction} from './framework/transaction'
import BigNum from 'bignum'
import {ethers} from 'ethers'
import {
    getBytes32FromIpfsCidV0,
    getIpfsCidV0FromBytes32
} from './framework/ipfs-bytes32'

chai.use(solidity)

describe('EthSignV4', () => {
    let contract: EthSignV4
    let s0: SignerWithAddress, s1: SignerWithAddress, s2: SignerWithAddress

    before(async () => {
        s0 = await signer(0)
        s1 = await signer(1)
        s2 = await signer(2)
    })

    beforeEach(async () => {
        contract = await deployContractWithProxy<EthSignV4>(
            'EthSignV4',
            1337,
            '0x0000000000000000000000000000000000000000'
        )
    })

    describe('encode & decode test', () => {
        it('should encode an address and step, then decode correctly', async () => {
            const step = 3
            const encodedValue = await contract.encodeSignerData(
                s0.address,
                step
            )
            const decodedValues = await contract.decodeSignerData(encodedValue)
            expect(decodedValues.signer).equals(s0.address)
            expect(decodedValues.step).equals(step)
            expect(decodedValues.hasSigned).equals(0)
            const encodedValueWithSignedFlag = new BigNum(
                encodedValue.toString()
            ).or(0x1)
            const decodedValuesWithSignedFlag = await contract.decodeSignerData(
                encodedValueWithSignedFlag.toString()
            )
            expect(decodedValuesWithSignedFlag.signer).equals(s0.address)
            expect(decodedValuesWithSignedFlag.step).equals(step)
            expect(decodedValuesWithSignedFlag.hasSigned).equals(1)
        })
    })

    describe('create and sign workflow', () => {
        const rawDataHash = ethers.utils.hashMessage('some data')
        const ipfsCid = 'QmNSUYVKDSvPUnRLKmuxk9diJ6yS96r1TrAXzjTiBcCLAL'
        const ipfsCidBytes32 = getBytes32FromIpfsCidV0(ipfsCid)
        const signers = [s0.address, s1.address, s2.address]
        const signerStep = [1, 1, 2]
        const signersPerStep = [2, 1]
        let signersData: [ethers.BigNumber]

        it('w/ strict mode, w/ no expiry', async () => {
            for (let i = 0; i < signers.length; ++i) {
                signersData.push(
                    await contract.encodeSignerData(signers[i], signerStep[i])
                )
            }
            const connectReceipt = await successfulTransaction(
                contract
                    .connect(s0)
                    .create(
                        true,
                        0,
                        rawDataHash,
                        ipfsCidBytes32,
                        signersPerStep,
                        signers,
                        signersData
                    )
            )
        })
    })
})
