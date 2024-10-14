// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IContentVerifiable {
    /// @notice Checks if the content is approved.
    /// @param initiator The submission account address.
    /// @param contentId The ID of the content.
    /// @return True if the content is approved, false otherwise.
    function isApproved(address initiator, uint256 contentId) external view returns (bool);

    /// @notice Checks if the content is active nor blocked.
    /// @param contentId The ID of the content.
    /// @return True if the content is active, false otherwise.
    function isActive(uint256 contentId) external view returns (bool);
}
