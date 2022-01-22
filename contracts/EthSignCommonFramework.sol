//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract EthSignCommonFramework is
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC2771ContextUpgradeable
{
    function initialize(address forwarder) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ERC2771Context_init(forwarder);
    }

    // solhint-disable-next-line ordering
    function pause() external onlyOwner {
        _pause();
        emit LogContractPaused();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit LogContractUnpaused();
    }

    event LogContractPaused();

    event LogContractUnpaused();

    /**
     * @dev Hashes the input string using `keccak256(abi.encodePacked())`.
     * @param uuid The input string, usually UUID v4. But really, this is no restriction.
     */
    function hashDocumentKey(string calldata uuid)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(uuid));
    }

    /**
     * @dev Verifies if a given ECDSA signature is authentic.
     * @param signer The signer's address.
     * @param hash The signed data, usually a hash.
     * @param signature The raw ECDSA signature.
     */
    function verifyECSignatureSigner(
        address signer,
        bytes32 hash,
        bytes calldata signature
    ) public view returns (bool) {
        return
            SignatureCheckerUpgradeable.isValidSignatureNow(
                signer,
                ECDSAUpgradeable.toEthSignedMessageHash(hash),
                signature
            );
    }

    /**
     * @dev Splits a given ECDSA signature into r, s, v.
     * @param signature The raw ECDSA signature.
     * @return r The r value of the ECDSA signature.
     * @return s The s value of the ECDSA signature.
     * @return v The v value of the ECDSA signature.
     */
    function splitECSignature(bytes memory signature)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return super._msgData();
    }
}
