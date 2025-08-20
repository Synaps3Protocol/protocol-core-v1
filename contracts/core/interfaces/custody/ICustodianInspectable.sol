// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ICustodianInspectable
/// @dev Interface for retrieving custodian enrollment data.
interface ICustodianInspectable {
    /// @notice Retrieves the total number of enrollments.
    /// @return The number of enrollments.
    function getEnrollmentCount() external view returns (uint256);
}
