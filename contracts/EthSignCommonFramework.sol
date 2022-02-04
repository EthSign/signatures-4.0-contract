//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";

contract EthSignCommonFramework is ERC2771ContextUpgradeable {
    uint256 public chainId;

    function initialize(uint256 chainId_, address forwarder)
        public
        virtual
        initializer
    {
        chainId = chainId_;
        __ERC2771Context_init(forwarder);
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
     * @dev Hashes the input string using `keccak256(abi.encodePacked())`.
     * @param str Input string.
     */
    function hashString(string calldata str) public pure returns (bytes32) {
        return keccak256(abi.encode(str));
    }
}
