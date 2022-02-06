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
        0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472; // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)");
    bytes32 private constant _STRUCT_TYPE_HASH =
        0x14bd91134e3467a07c38fd0cbaa1e572cbf6bab435886649b8818f6754865054; // keccak256("Contract(bytes32 contractId,bytes32 rawDataHash)");
    // solhint-disable var-name-mixedcase
    bytes32 private _DOMAIN_SEPARATOR;

    mapping(bytes32 => Contract) internal _contractMapping;

    event SignersAdded(bytes32 contractId, address[] signers);
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
                0x13600b294191fc92924bb3ce4b969c1e7e2bab8f4c93c3fc6d0a51733df3c060, // keccak256("4")
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
        uint8[] calldata signersPerStep,
        address[] calldata signers,
        uint168[] calldata signersData
    ) external returns (bytes32 contractId) {
        contractId = keccak256(abi.encode(chainId, ipfsCIDv0_));
        Contract storage c = _contractMapping[contractId];
        require(c.ipfsCIDv0 == 0, "Contract exists");
        require(expiry_ > block.timestamp || expiry_ == 0, "Invalid expiry");
        require(signers.length == signersData.length, "Arrays mismatch 0");
        emit SignersAdded(contractId, signers);
        uint256 totalSigners = 0;
        for (uint256 j = 0; j < signersPerStep.length; ++j) {
            totalSigners += signersPerStep[j];
        }
        require(totalSigners == signers.length, "Arrays mismatch 1");
        c.strictMode = strictMode_;
        c.expiry = expiry_;
        c.rawDataHash = rawDataHash_;
        c.ipfsCIDv0 = ipfsCIDv0_;
        c.signersLeftPerStep = signersPerStep;
        c.packedSignersAndStatus = signersData;
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
                ECDSAUpgradeable.toTypedDataHash(
                    _DOMAIN_SEPARATOR,
                    _hashStruct(contractId, c.rawDataHash)
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
            step == 1 || c.signersLeftPerStep[step - 1] == 0,
            "Not your turn"
        );
        require(c.expiry == 0 || c.expiry > block.timestamp, "Expired");
        c.packedSignersAndStatus[index] |= 0x1;
        c.signersLeftPerStep[step] -= 1;
        if (c.strictMode) c.ipfsCIDv0 = ipfsCIDv0_;
        emit SignerSigned(contractId, _msgSender(), ipfsCIDv0_);
        if (
            c.signersLeftPerStep[step] == 0 &&
            step == c.signersLeftPerStep.length
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

    function _hashStruct(bytes32 contractId, bytes32 rawDataHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(abi.encode(_STRUCT_TYPE_HASH, contractId, rawDataHash));
    }
}
