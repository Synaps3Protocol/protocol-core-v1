// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { QuorumUpgradeable } from "@synaps3/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { IAssetReferendum } from "@synaps3/core/interfaces/assets/IAssetReferendum.sol";
import { T } from "@synaps3/core/primitives/Types.sol";
import { C } from "@synaps3/core/primitives/Constants.sol";

/// @title AssetReferendum
/// @notice This contract enables a decentralized governance process for asset submission/voting/approval/rejection.
/// @dev Implements a quorum-based mechanism for governance approval of assets in the system.
contract AssetReferendum is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    QuorumUpgradeable,
    IAssetReferendum
{
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev Mapping that tracks content submissions for each address.
    /// Each address maps to a set of asset IDs (UintSet) that have been submitted by that address.
    mapping(address => EnumerableSet.UintSet) private _submissions;

    /// @dev Event emitted when a content is submitted for referendum.
    /// @param assetId The ID of the asset that has been submitted.
    /// @param initiator The address of the initiator who submitted the asset.
    event Submitted(address indexed initiator, uint256 assetId);

    /// @dev Event emitted when a content is approved.
    /// @param assetId The ID of the asset that has been approved.
    event Approved(uint256 assetId);

    /// @dev Event emitted when a content is revoked.
    /// @param assetId The ID of the asset that has been revoked.
    event Revoked(uint256 assetId);

    /// @dev Event emitted when a content is rejected.
    /// @param assetId The ID of the asset that has been rejected.
    event Rejected(uint256 assetId);

    /// @dev Error thrown when asset submission fails.
    /// @param initiator The address of the user who attempted to submit the asset.
    /// @param assetId The ID of the asset that failed to be registered.
    error SubmissionFailed(address initiator, uint256 assetId);

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
        __AccessControlled_init(accessManager);
    }

    /// @notice Submits a content proposition for referendum.
    /// @param assetId The ID of the asset to be submitted.
    /// @dev The asset ID is reviewed by governance.
    function submit(uint256 assetId) external {
        // if the asset was not already present `added` = true;
        bool added = _submissions[msg.sender].add(assetId);
        if (!added) revert SubmissionFailed(msg.sender, assetId);
        _register(assetId); // set the assets as waiting approval state
        emit Submitted(msg.sender, assetId);
    }

    // /// @notice Submits a content proposition for referendum with a signature.
    // /// @param assetId The ID of the asset to be submitted.
    // /// @param sig The EIP712 signature for the submission.
    // function submitWithSig(uint256 assetId, T.EIP712Signature calldata sig) external {
    //     // https://eips.ethereum.org/EIPS/eip-712
    //     bytes32 structHash = keccak256(
    //         abi.encode(C.REFERENDUM_SUBMIT_TYPEHASH, assetId, sig.signer, _useNonce(sig.signer))
    //     );

    //     // retrieve the signer from digest and register the resultant signer as initiator.
    //     // expected keccak256("\x19\x01" ‖ domainSeparator ‖ hashStruct(message))
    //     bytes32 digest = _hashTypedDataV4(structHash);
    //     address initiator = ecrecover(digest, sig.v, sig.r, sig.s);
    //     if (initiator == address(0) || sig.signer != initiator) revert InvalidSubmissionSignature();
    //     _submit(assetId, initiator);
    // }

    /// @notice Revoke an approved content.
    /// @param assetId The ID of the asset to be revoked.
    function revoke(uint256 assetId) external restricted {
        _revoke(assetId); // bundled check-effects-interaction
        emit Revoked(assetId);
    }

    /// @notice Reject a content proposition.
    /// @param assetId The ID of the asset to be rejected.
    function reject(uint256 assetId) external restricted {
        _block(assetId); // bundled check-effects-interaction
        emit Rejected(assetId);
    }

    /// @notice Approves a content proposition.
    /// @param assetId The ID of the asset to be approved.
    function approve(uint256 assetId) external restricted {
        _approve(assetId); // bundled check-effects-interaction
        emit Approved(assetId);
    }

    /// @notice Checks if the asset is approved.
    /// @param initiator The submission account address .
    /// @param assetId The ID of the asset.
    function isApproved(address initiator, uint256 assetId) external view returns (bool) {
        bool approved = isActive(assetId);
        bool validAccount = _submissions[initiator].contains(assetId);
        bool verifiedRole = _hasRole(C.VER_ROLE, initiator);
        // is approved with a valid submission account or is verified account..
        return (approved && validAccount) || verifiedRole;
    }

    /// @notice Checks if the asset is active nor blocked.
    /// @param assetId The ID of the asset.
    function isActive(uint256 assetId) public view returns (bool) {
        return _status(assetId) == T.Status.Active;
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
