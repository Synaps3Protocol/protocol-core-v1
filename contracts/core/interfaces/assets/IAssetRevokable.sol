// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IAssetRevokable Interface
/// @notice Defines the functions for invalidating or withdrawing assets from the system.
/// @dev This interface focuses on asset rejection and revocation, used in the governance lifecycle.
interface IAssetRevokable {
    /// @notice Rejects an asset proposition in the referendum.
    /// @dev If rejected, the asset cannot be used in the system unless resubmitted.
    /// @param assetId The unique identifier of the asset to be rejected.
    function reject(uint256 assetId) external;

    /// @notice Revokes a previously approved asset.
    /// @dev This function allows the system to remove approval from an asset, disabling its functionality.
    /// @param assetId The unique identifier of the asset to be revoked.
    function revoke(uint256 assetId) external;
}
