// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IAssetRegistrable Interface
/// @notice Defines the essential functions for managing asset registration and governance through a referendum process.
/// @dev This interface mirrors the FSM behavior from `IQuorum`, but scoped to asset governance.
interface IAssetRegistrable {
    /// @notice Submits a new asset proposition for a referendum.
    /// @dev This function should allow entities to propose an asset for approval.
    /// @param assetId The unique identifier of the asset being submitted.
    function submit(uint256 assetId) external;

    /// @notice Approves an asset proposition in the referendum.
    /// @dev Once approved, the asset is considered verified and usable within the system.
    /// @param assetId The unique identifier of the asset to be approved.
    function approve(uint256 assetId) external;

    /// @notice Rejects an asset proposition in the referendum.
    /// @dev If rejected, the asset cannot be used in the system unless resubmitted.
    /// @param assetId The unique identifier of the asset to be rejected.
    function reject(uint256 assetId) external;

    /// @notice Revokes a previously approved asset.
    /// @dev This function allows the system to remove approval from an asset, disabling its functionality.
    /// @param assetId The unique identifier of the asset to be revoked.
    function revoke(uint256 assetId) external;
}
