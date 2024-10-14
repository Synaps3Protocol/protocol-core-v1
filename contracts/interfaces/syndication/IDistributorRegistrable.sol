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

    /// @notice Retrieves the enrollment time for a distributor, based on the current block time and expiration period.
    /// @param distributor The address of the distributor.
    /// @return The enrollment time in seconds.
    function getEnrollmentTime(address distributor) external view returns (uint256);

    /// @notice Retrieves the total number of enrollments.
    /// @return The count of enrollments.
    function getEnrollmentCount() external view returns (uint256);

    /// @notice Retrieves the current expiration period for enrollments or registrations.
    /// @return The expiration period, in seconds.
    function getExpirationPeriod() external view returns (uint256);
}