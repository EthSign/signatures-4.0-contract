//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

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
     * @dev Hashes the input string using `keccak256(abi.encodePacked())`.
     * @param str Input string.
     */
    function hashString(string calldata str) public pure returns (bytes32) {
        return keccak256(abi.encode(str));
    }
}
