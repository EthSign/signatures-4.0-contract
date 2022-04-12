//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract EthSignPublicEncryptionKeyRegistry is ERC2771Context {
    mapping(address => string) public registry;

    event Registered(address entity, string publicEncryptionKey);

    constructor(address forwarder) ERC2771Context(forwarder) {}

    function register(string calldata publicEncryptionKey) external {
        registry[_msgSender()] = publicEncryptionKey;
        emit Registered(_msgSender(), publicEncryptionKey);
    }
}
