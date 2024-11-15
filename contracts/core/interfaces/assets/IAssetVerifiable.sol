// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IAssetVerifiable {
    /// @notice Checks if the asset is approved.
    /// @param initiator The submission account address.
    /// @param assetId The ID of the asset.
    function isApproved(address initiator, uint256 assetId) external view returns (bool);

    /// @notice Checks if the asset is active nor blocked.
    /// @param assetId The ID of the asset.
    function isActive(uint256 assetId) external view returns (bool);
}
