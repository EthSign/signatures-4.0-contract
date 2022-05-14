//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "./EthSignCommonFramework.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";

contract EthSignV4 is EthSignCommonFramework {
    struct Contract {
        uint32 expiry;
        string rawDataHash;
        uint8[] signersLeftPerStep;
        uint168[] packedSignersAndStatus;
    }
    /**
        uint168[] packedSignersAndStatus:
        |  |
        |   -> 8th~1st bits => Metadata
        |
         -> Upper 168th~9th bits => Signer's address (160 bits)
        
        Metadata:
        - 8th~2nd bits => The step (in terms of ordering) this signer is in: max 127
        - 1st bit => Boolean indicating if the signer has signed
     */
    uint8 public constant STEP_BITMASK = 0xFE;
    uint8 public constant STATUS_BITMASK = 0x1;
    bytes32 private constant _SALT = keccak256("EthSignV4");
    bytes32 private constant _EIP712_DOMAIN_TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
        );
    bytes32 private constant _STRUCT_TYPE_HASH =
        keccak256(
            "Contract(bytes32 contractId,string rawDataHash,string rawSignatureDataHash)"
        );
    // solhint-disable var-name-mixedcase
    bytes32 private _DOMAIN_SEPARATOR;

    mapping(bytes32 => Contract) internal _contractMapping;

    event ContractCreated(bytes32 contractId, string name, address initiator);
    event RecipientsAdded(
        bytes32 contractId,
        uint168[] signersData,
        address[] viewers
    );
    event SignerSigned(
        bytes32 contractId,
        address signer,
        string rawSignatureDataHash
    );
    event ContractSigningCompleted(bytes32 contractId);
    event ContractHidden(bytes32 contractId, address party);

    function initialize(uint256 chainId_, address forwarder)
        public
        override
        initializer
    {
        super.initialize(chainId_, forwarder);
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPE_HASH,
                keccak256("EthSign"),
                keccak256("4"),
                chainId,
                this,
                _SALT
            )
        );
    }

    // solhint-disable ordering
    function create(
        string calldata name,
        uint32 expiry_,
        string calldata rawDataHash_,
        uint8[] calldata signersPerStep,
        uint168[] calldata signersData,
        address[] calldata viewers
    ) external returns (bytes32 contractId) {
        contractId = keccak256(
            abi.encode(
                chainId,
                name,
                expiry_,
                rawDataHash_,
                signersPerStep,
                signersData
            )
        );
        Contract storage c = _contractMapping[contractId];
        require(c.packedSignersAndStatus.length == 0, "Contract exists");
        // slither-disable-next-line timestamp
        require(expiry_ > block.timestamp || expiry_ == 0, "Invalid expiry");
        emit ContractCreated(contractId, name, _msgSender());
        emit RecipientsAdded(contractId, signersData, viewers);
        c.expiry = expiry_;
        c.rawDataHash = rawDataHash_;
        c.signersLeftPerStep = signersPerStep;
        c.packedSignersAndStatus = signersData;
    }

    function sign(
        bytes32 contractId,
        uint256 index,
        bytes calldata signature,
        string calldata rawSignatureDataHash
    ) external {
        Contract storage c = _contractMapping[contractId];
        require(
            SignatureCheckerUpgradeable.isValidSignatureNow(
                _msgSender(),
                ECDSAUpgradeable.toTypedDataHash(
                    _DOMAIN_SEPARATOR,
                    _hashSign(contractId, c.rawDataHash, rawSignatureDataHash)
                ),
                signature
            ),
            "Invalid signature"
        );
        uint256 step = (c.packedSignersAndStatus[index] & STEP_BITMASK) >> 1;
        require(
            address(uint160(c.packedSignersAndStatus[index] >> 8)) ==
                _msgSender(),
            "Signer mismatch"
        );
        require(
            c.packedSignersAndStatus[index] & STATUS_BITMASK == 0x0,
            "Already signed"
        );
        require(
            step == 0 || c.signersLeftPerStep[step - 1] == 0,
            "Not your turn"
        );
        require(c.expiry == 0 || c.expiry > block.timestamp, "Expired");
        c.packedSignersAndStatus[index] |= 0x1;
        c.signersLeftPerStep[step] -= 1;
        emit SignerSigned(contractId, _msgSender(), rawSignatureDataHash);
        if (
            c.signersLeftPerStep[step] == 0 &&
            step == c.signersLeftPerStep.length - 1
        ) emit ContractSigningCompleted(contractId);
    }

    function hide(bytes32 contractId) external {
        emit ContractHidden(contractId, _msgSender());
    }

    function getContract(bytes32 contractId)
        external
        view
        returns (Contract memory)
    {
        return _contractMapping[contractId];
    }

    function encodeSignerData(address signer, uint8 step)
        external
        pure
        returns (uint168 encodedSignerData)
    {
        require(step < STEP_BITMASK, "Step out of range");
        encodedSignerData = uint168(uint160(signer)) << 8;
        uint16 shiftedStep = step << 1;
        encodedSignerData |= shiftedStep;
    }

    function decodeSignerData(uint168 signerData)
        external
        pure
        returns (
            address signer,
            uint8 step,
            uint8 hasSigned
        )
    {
        signer = address(uint160(signerData >> 8));
        step = uint8((signerData & STEP_BITMASK) >> 1);
        hasSigned = uint8(signerData & STATUS_BITMASK);
    }

    function _hashSign(
        bytes32 contractId,
        string memory rawDataHash,
        string memory rawSignatureDataHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _STRUCT_TYPE_HASH,
                    contractId,
                    keccak256(bytes(rawDataHash)),
                    keccak256(bytes(rawSignatureDataHash))
                )
            );
    }
}
