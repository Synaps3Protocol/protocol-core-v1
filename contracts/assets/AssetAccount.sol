// SPDX-License-Identifier: MIT

// TODO amplify features for ownership
// - Holds metrics, such as usage and other operational data.
// - Enables specific restrictions and terms for granular control over the asset.
// - Whitelists policies to operate over the asset, allowing fine-grained control:
//   e.g., an asset can be restricted to allow access only through rental policies.

// Can be attached in the future to existing assets as an "enhancement"
// to add granular conditions and use these conditions in policy validation.

pragma solidity ^0.8.0;

import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { IAssetOwnership } from "contracts/core/interfaces/assets/IAssetOwnership.sol";
import { MetricsOps } from "@synaps3/core/libraries/MetricsOps.sol";

// TODO WIP
// pending impl https://eips.ethereum.org/EIPS/eip-6551#account-interface

/// @title AssetAccount
/// @notice A contract representing a bounded account tied to a specific asset. It adds
///         functionality for managing restrictions, metrics, and policies over the asset.
contract AssetAccount {
    /// @dev Interface for asset ownership to check and manage asset ownership details.
    IAssetOwnership public immutable ASSET_OWNERSHIP;
    
    /// @dev The ID of the asset associated with this account.
    uint256 public assetId;
    /// @dev Mapping to store addresses of users restricted from accessing this asset.
    mapping(address => bool) private restrictedUsers;
    
    /// @notice Event emitted when a user is restricted from accessing the asset.
    /// @param user The address of the restricted user.
    event UserRestricted(address indexed user);

    /// @notice Modifier to restrict access to functions to the asset owner only.
    modifier onlyOwner() {
        address owner = ASSET_OWNERSHIP.ownerOf(assetId);
        require(msg.sender == owner, "Not the owner");
        _;
    }

    /// @param assetOwnership The address of the contract managing asset ownership.
    /// @param assetId_ The ID of the asset associated with this account.
    constructor(address assetOwnership, uint256 assetId_) {
        ASSET_OWNERSHIP = IAssetOwnership(assetOwnership);
        assetId = assetId_;
    }

    /// @notice Restricts a specific user from accessing this asset.
    /// @dev Only the asset owner can restrict users.
    /// @param account The address of the account to restrict.
    function restrictUser(address account) external onlyOwner {
        restrictedUsers[account] = true;
        emit UserRestricted(account);
    }

    /// @notice Registers a metric for a policy, such as usage or access data.
    /// @dev This function logs metrics in the context of the current sender. It uses
    ///      `MetricsOps` to handle metric recording and context.
    /// @param metric The name of the metric (e.g., "access_count").
    /// @param value The value of the metric to register.
    function registerMetric(string calldata metric, uint256 value) external {
        // Encode the sender's address to provide context for the metric.
        bytes memory emitter = abi.encode(msg.sender);
        MetricsOps.logMetricWithContext(metric, value, emitter);
    }

    /// @notice Checks if a user is restricted from accessing the asset.
    /// @param account The address of the account to check.
    /// @return True if the user is restricted, false otherwise.
    function isUserRestricted(address account) external view returns (bool) {
        return restrictedUsers[account];
    }
}
