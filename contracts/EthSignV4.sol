//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./EthSignCommonFramework.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";

contract EthSignV4 is EthSignCommonFramework {
    struct Contract {
        bool strictMode;
        uint32 expiry;
        bytes32 rawDataHash;
        bytes32 ipfsCIDv0;
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
    bytes32 private constant _SALT =
        0xad27b301e5f37100ff157cc76d31929cff6e67812684f9f8bc3d7f70865dd810; // keccak256("EthSignV4");
    bytes32 private constant _EIP712_DOMAIN_TYPE_HASH =
        0xba3bbab4b37e6e20d315843d8bced25060386a557eeb60eefdbb4096f6ad6923; // keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract,bytes32 salt)");
    bytes32 private constant _STRUCT_TYPE_HASH =
        0x8165517356929917aaedab33f6f3c5e0284dcaec7dcf7dcceaaf1ed3be764cd4; // keccak256("Contract(uint32 expiry, bytes32 rawDataHash)");
    // solhint-disable var-name-mixedcase
    bytes32 private _DOMAIN_SEPARATOR;

    mapping(bytes32 => Contract) internal _contractMapping;

    event SignerAdded(bytes32 contractId, address signer);
    event SignerSigned(bytes32 contractId, address signer, bytes32 ipfsCIDv0);
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
                0x60570743c3aa81622759289f024257add09e8c4aa0cf1732651de4dd5231d716, // keccak256("EthSign")
                chainId,
                this,
                _SALT
            )
        );
    }

    // solhint-disable ordering
    function create(
        bool strictMode_,
        uint32 expiry_,
        bytes32 rawDataHash_,
        bytes32 ipfsCIDv0_,
        address[] calldata signers,
        uint8[] calldata signersPerStep
    ) external {
        bytes32 contractId = keccak256(abi.encode(chainId, ipfsCIDv0_));
        Contract storage c = _contractMapping[contractId];
        require(c.ipfsCIDv0 == 0, "Contract exists");
        require(expiry_ > block.timestamp, "Invalid expiry");
        uint168[] memory temp = new uint168[](signers.length);
        for (uint256 i = 0; i < signers.length; ++i) {
            temp[i] = uint168(uint160(signers[i])) << 8;
            emit SignerAdded(contractId, signers[i]);
        }
        c.strictMode = strictMode_;
        c.expiry = expiry_;
        c.rawDataHash = rawDataHash_;
        c.ipfsCIDv0 = ipfsCIDv0_;
        c.signersLeftPerStep = signersPerStep;
        c.packedSignersAndStatus = temp;
    }

    function sign(
        bytes32 contractId,
        uint256 index,
        bytes32 ipfsCIDv0_,
        bytes calldata signature
    ) external {
        Contract storage c = _contractMapping[contractId];
        require(
            SignatureCheckerUpgradeable.isValidSignatureNow(
                _msgSender(),
                _hashStruct(c.expiry, c.rawDataHash),
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
        c.packedSignersAndStatus[index] |= 0x1;
        c.signersLeftPerStep[step] -= 1;
        if (c.strictMode) c.ipfsCIDv0 = ipfsCIDv0_;
        emit SignerSigned(contractId, _msgSender(), ipfsCIDv0_);
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

    function _hashStruct(uint32 expiry, bytes32 rawDataHash)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    _DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(_STRUCT_TYPE_HASH, expiry, rawDataHash)
                    )
                )
            );
    }
}
