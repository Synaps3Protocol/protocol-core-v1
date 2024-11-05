// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { NoncesUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { AccessControlledUpgradeable } from "contracts/base/upgradeable/AccessControlledUpgradeable.sol";
import { QuorumUpgradeable } from "contracts/base/upgradeable/QuorumUpgradeable.sol";
import { IContentReferendum } from "contracts/interfaces/content/IContentReferendum.sol";

import { C } from "contracts/libraries/Constants.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title Content curation contract.
/// @notice This contract allows for the submission, voting, and approval/rejection of content.
contract ContentReferendum is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    NoncesUpgradeable,
    EIP712Upgradeable,
    QuorumUpgradeable,
    IContentReferendum
{
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev Mapping that tracks content submissions for each address.
    /// Each address maps to a set of content IDs (UintSet) that have been submitted by that address.
    mapping(address => EnumerableSet.UintSet) private _submissions;

    /// @dev Event emitted when a content is submitted for referendum.
    /// @param contentId The ID of the content that has been submitted.
    /// @param initiator The address of the initiator who submitted the content.
    /// @param timestamp The timestamp indicating when the content was submitted.
    event Submitted(address indexed initiator, uint256 timestamp, uint256 contentId);

    /// @dev Event emitted when a content is approved.
    /// @param contentId The ID of the content that has been approved.
    /// @param timestamp The timestamp indicating when the content was approved.
    event Approved(uint256 contentId, uint256 timestamp);

    /// @dev Event emitted when a content is revoked.
    /// @param contentId The ID of the content that has been revoked.
    /// @param timestamp The timestamp indicating when the content was revoked.
    event Revoked(uint256 contentId, uint256 timestamp);

    /// @dev Event emitted when a content is rejected.
    /// @param contentId The ID of the content that has been rejected.
    /// @param timestamp The timestamp indicating when the content was revoked.
    event Rejected(uint256 contentId, uint256 timestamp);

    /// @dev Error thrown when the content submission is invalid (e.g., incorrect or missing data).
    error InvalidSubmissionContent();

    /// @dev Error thrown when the signature of the content submission is invalid.
    error InvalidSubmissionSignature();

    /// @dev Error thrown when the initiator of the submission is invalid (e.g., not authorized to submit content).
    error InvalidSubmissionInitiator();

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @notice This constructor prevents the implementation contract from being initialized.
    /// @dev See https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
    /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    function initialize(address accessManager) public initializer {
        __Quorum_init();
        __UUPSUpgradeable_init();
        __EIP712_init("Referendum", "1");
        __AccessControlled_init(accessManager);
    }

    /// @notice Submits a content proposition for referendum.
    /// @param contentId The ID of the content to be submitted.
    /// @dev The content ID is reviewed by governance.
    function submit(uint256 contentId) external {
        _submit(contentId, msg.sender);
    }

    /// @notice Submits a content proposition for referendum with a signature.
    /// @param contentId The ID of the content to be submitted.
    /// @param sig The EIP712 signature for the submission.
    function submitWithSig(uint256 contentId, T.EIP712Signature calldata sig) external {
        // https://eips.ethereum.org/EIPS/eip-712
        bytes32 structHash = keccak256(
            abi.encode(C.REFERENDUM_SUBMIT_TYPEHASH, contentId, sig.signer, _useNonce(sig.signer))
        );

        // retrieve the signer from digest and register the resultant signer as initiator.
        // expected keccak256("\x19\x01" ‖ domainSeparator ‖ hashStruct(message))
        bytes32 digest = _hashTypedDataV4(structHash);
        address initiator = ecrecover(digest, sig.v, sig.r, sig.s);
        if (initiator == address(0) || sig.signer != initiator) revert InvalidSubmissionSignature();
        _submit(contentId, initiator);
    }

    /// @notice Checks if the content is active nor blocked.
    /// @param contentId The ID of the content.
    function isActive(uint256 contentId) public view returns (bool) {
        return _status(contentId) == Status.Active;
    }

    /// @notice Checks if the content is approved.
    /// @param initiator The submission account address .
    /// @param contentId The ID of the content.
    function isApproved(address initiator, uint256 contentId) public view returns (bool) {
        bool approved = isActive(contentId);
        bool validAccount = _submissions[initiator].contains(contentId);
        // TODO role manager check
        bool verifiedRole = _hasRole(C.VERIFIED_ROLE, initiator);
        // is approved with a valid submission account or is verified account..
        return (approved && validAccount) || verifiedRole;
    }

    /// @notice Revoke an approved content.
    /// @param contentId The ID of the content to be revoked.
    function revoke(uint256 contentId) public onlyGov {
        _revoke(contentId); // bundled check-effects-interaction
        emit Revoked(contentId, block.timestamp);
    }

    /// @notice Reject a content proposition.
    /// @param contentId The ID of the content to be rejected.
    function reject(uint256 contentId) public onlyGov {
        _block(contentId); // bundled check-effects-interaction
        emit Rejected(contentId, block.timestamp);
    }

    /// @notice Approves a content proposition.
    /// @param contentId The ID of the content to be approved.
    function approve(uint256 contentId) public onlyGov {
        _approve(contentId); // bundled check-effects-interaction
        emit Approved(contentId, block.timestamp);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Submits content for registration and tracks the submission for the initiator.
    /// @dev This function registers the content, records the submission, and emits an event.
    /// @param contentId The unique identifier of the content being submitted.
    /// @param initiator The address of the entity initiating the content submission.
    function _submit(uint256 contentId, address initiator) private {
        _register(contentId); // bundled check-effects-interaction
        _submissions[initiator].add(contentId);
        emit Submitted(initiator, block.timestamp, contentId);
    }
}
