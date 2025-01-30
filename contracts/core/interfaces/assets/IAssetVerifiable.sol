// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IAssetVerifiable
/// @notice Interface for verifying the approval and active status of assets.
/// @dev This interface is used to check whether an asset has been approved and whether it is currently active.
interface IAssetVerifiable {
    /// @notice Checks if a given asset has been approved.
    /// @dev This function verifies if the asset has passed the necessary approval process.
    /// @param initiator The address that submitted the asset for approval.
    /// @param assetId The unique identifier of the asset.
    /// @return A boolean indicating whether the asset is approved (`true`) or not (`false`).
    function isApproved(address initiator, uint256 assetId) external view returns (bool);

    /// @notice Checks if a given asset is active and not blocked.
    /// @dev Ensures that the asset is currently in use and has not been disabled or blacklisted.
    /// @param assetId The unique identifier of the asset.
    /// @return A boolean indicating whether the asset is active (`true`) or inactive/blocked (`false`).
    function isActive(uint256 assetId) external view returns (bool);
}
