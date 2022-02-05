import {base58} from 'ethers/lib/utils'

export function getBytes32FromIpfsCidV0(cid: string) {
    return '0x' + Buffer.from(base58.decode(cid).slice(2)).toString('hex')
}

export function getIpfsCidV0FromBytes32(bytes32Hex: string) {
    const hashHex = '1220' + bytes32Hex.slice(2)
    const hashBytes = Buffer.from(hashHex, 'hex')
    const hashStr = base58.encode(hashBytes)
    return hashStr
}
