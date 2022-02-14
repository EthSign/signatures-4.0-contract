//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

contract EthSignCommonFramework is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ERC2771ContextUpgradeable
{
    uint256 public chainId;

    function initialize(uint256 chainId_, address forwarder)
        public
        virtual
        initializer
    {
        chainId = chainId_;
        __UUPSUpgradeable_init();
        __ERC2771Context_init(forwarder);
        __Ownable_init_unchained();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return super._msgSender();
    }

    // slither-disable-next-line dead-code
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
