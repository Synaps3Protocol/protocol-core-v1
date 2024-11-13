// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IAssetVerifiable {
    /// @notice Checks if the content is approved.
    /// @param initiator The submission account address.
    /// @param contentId The ID of the content.
    function isApproved(address initiator, uint256 contentId) external view returns (bool);

    /// @notice Checks if the content is active nor blocked.
    /// @param contentId The ID of the content.
    function isActive(uint256 contentId) external view returns (bool);
}
