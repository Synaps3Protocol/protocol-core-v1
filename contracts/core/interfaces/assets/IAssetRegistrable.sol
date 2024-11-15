// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IAssetRegistrable Interface
/// @notice This interface defines the essential functions for a referendum contract.
/// @dev Implement this interface to create a referendum contract.
interface IAssetRegistrable {
    /// @notice Submits a new proposition for referendum.
    /// @param assetId The ID of the asset to be submitted.
    function submit(uint256 assetId) external;

    /// @notice Approves a proposition in the referendum.
    /// @param assetId The ID of the asset to be approved.
    function approve(uint256 assetId) external;

    /// @notice Rejects a proposition in the referendum.
    /// @param assetId The ID of the asset to be rejected.
    function reject(uint256 assetId) external;

    /// @notice Revoke an approved content.
    /// @param assetId The ID of the asset to be revoked.
    function revoke(uint256 assetId) external;
}
