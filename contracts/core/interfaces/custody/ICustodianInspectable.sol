// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ICustodianInspectable
/// @dev Interface for retrieving custodian enrollment data.
interface ICustodianInspectable {
    /// @notice Retrieves the enrollment deadline for a custodian.
    /// @param custodian The address of the custodian.
    /// @return The enrollment deadline timestamp.
    function getEnrollmentDeadline(address custodian) external view returns (uint256);

    /// @notice Retrieves the total number of enrollments.
    /// @return The number of enrollments.
    function getEnrollmentCount() external view returns (uint256);
}
