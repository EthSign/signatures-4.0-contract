// Start - Support direct Mocha run & debug
import hre from 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
import {deployContractWithProxy, signer} from './framework/contracts'
import {EthSignV4} from '../typechain'
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers'
import {successfulResolvedTransaction} from './framework/transaction'
import BigNum from 'bignum'
import {ethers} from 'ethers'
import {
    getBytes32FromIpfsCidV0,
    getIpfsCidV0FromBytes32
} from './framework/ipfs-bytes32'

chai.use(solidity)

const chainId = hre.network.config.chainId ?? 1337

const EIP712_CONSTANTS = {
    DOMAIN_DATA: {
        name: 'EthSign',
        version: '4',
        chainId: chainId,
        verifyingContract: '',
        salt: '0xad27b301e5f37100ff157cc76d31929cff6e67812684f9f8bc3d7f70865dd810'
    },
    STRUCT_TYPES: {
        Contract: [
            {name: 'contractId', type: 'bytes32'},
            {name: 'rawDataHash', type: 'bytes32'}
        ]
    }
}

describe('EthSignV4', () => {
    let contract: EthSignV4
    let s0: SignerWithAddress, s1: SignerWithAddress, s2: SignerWithAddress
    let signerAddresses: string[]

    before(async () => {
        s0 = await signer(0)
        s1 = await signer(1)
        s2 = await signer(2)
        signerAddresses = []
        signerAddresses.push(s0.address)
        signerAddresses.push(s1.address)
        signerAddresses.push(s2.address)
    })

    beforeEach(async () => {
        contract = await deployContractWithProxy<EthSignV4>(
            'EthSignV4',
            chainId,
            '0x0000000000000000000000000000000000000000'
        )
        EIP712_CONSTANTS.DOMAIN_DATA.verifyingContract = contract.address
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
        const signerStep = [1, 1, 2]
        const signersPerStep = [2, 1]
        const signersData: ethers.BigNumber[] = []

        before(async () => {
            for (let i = 0; i < signerAddresses.length; ++i) {
                signersData.push(
                    await contract.encodeSignerData(
                        signerAddresses[i],
                        signerStep[i]
                    )
                )
            }
        })

        it('w/ strict mode, w/ no expiry', async () => {
            const contractId = await contract
                .connect(s0)
                .callStatic.create(
                    true,
                    0,
                    rawDataHash,
                    ipfsCidBytes32,
                    signersPerStep,
                    signerAddresses,
                    signersData
                )
            // Create
            const createTx = await contract
                .connect(s0)
                .create(
                    true,
                    0,
                    rawDataHash,
                    ipfsCidBytes32,
                    signersPerStep,
                    signerAddresses,
                    signersData
                )
            await successfulResolvedTransaction(createTx)
            void expect(createTx)
                .to.emit(contract, 'SignersAdded')
                .withArgs(contractId, signerAddresses)
            // Verify struct
            const contractStruct = await contract.getContract(contractId)
            expect(contractStruct.strictMode).equals(true)
            expect(contractStruct.expiry).equals(0)
            expect(contractStruct.rawDataHash).equals(rawDataHash)
            expect(getIpfsCidV0FromBytes32(contractStruct.ipfsCIDv0)).equals(
                ipfsCid
            )
            expect(contractStruct.signersLeftPerStep).to.deep.equal(
                signersPerStep
            )
            let i = 0
            await Promise.all(
                contractStruct.packedSignersAndStatus.map(async (v) => {
                    const decodedValues = await contract.decodeSignerData(v)
                    expect(decodedValues.signer).equals(signerAddresses[i])
                    expect(decodedValues.step).equals(signerStep[i])
                    expect(decodedValues.hasSigned).equals(0)
                    ++i
                })
            )
            // Sign
            const ipfsCid_ = getBytes32FromIpfsCidV0(
                'QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR'
            )
            const message = {contractId: contractId, rawDataHash: rawDataHash}
            const s0Signature = await s0._signTypedData(
                EIP712_CONSTANTS.DOMAIN_DATA,
                EIP712_CONSTANTS.STRUCT_TYPES,
                message
            )
            const signTx = await contract
                .connect(s0)
                .sign(contractId, 0, ipfsCid_, s0Signature)
            await successfulResolvedTransaction(signTx)
            void expect(signTx)
                .to.emit(contract, 'SignerSigned')
                .withArgs(contractId, s0.address, ipfsCid_)
        })
    })
})
