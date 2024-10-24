// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IContentRegistrable Interface
/// @notice This interface defines the essential functions for a referendum contract.
/// @dev Implement this interface to create a referendum contract.
interface IContentRegistrable {
    /// @notice Submits a new proposition for referendum.
    /// @param contentId The ID of the content to be submitted.
    function submit(uint256 contentId) external;

    /// @notice Approves a proposition in the referendum.
    /// @param contentId The ID of the content to be approved.
    function approve(uint256 contentId) external;

    /// @notice Rejects a proposition in the referendum.
    /// @param contentId The ID of the content to be rejected.
    function reject(uint256 contentId) external;

    /// @notice Revoke an approved content.
    /// @param contentId The ID of the content to be revoked.
    function revoke(uint256 contentId) external;
}
