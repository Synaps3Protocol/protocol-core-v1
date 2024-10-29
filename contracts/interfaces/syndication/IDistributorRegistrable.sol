// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IDistributorRegistrable
/// @dev Interface for managing distributors registration.
interface IDistributorRegistrable {
    /// @notice Registers data with a given identifier.
    /// @param distributor The address of the distributor to register.
    /// @param currency The currency used to pay enrollment.
    function register(address distributor, address currency) external payable;

    /// @notice Approves the data associated with the given identifier.
    /// @param distributor The address of the distributor to approve.
    function approve(address distributor) external;

    /// @notice Revokes the registration of an entity.
    /// @param distributor The address of the distributor to revoke.
    function revoke(address distributor) external;

    /// @notice Retrieves the enrollment deadline for a distributor.
    /// @param distributor The address of the distributor.
    function getEnrollmentDeadline(address distributor) external view returns (uint256);

    /// @notice Retrieves the total number of enrollments.
    function getEnrollmentCount() external view returns (uint256);
}
