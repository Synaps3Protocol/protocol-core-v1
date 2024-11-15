// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Distributor Expirable Interface
/// @notice This interface defines the methods for managing expiration periods
/// related to enrollments or registrations.
interface IDistributorExpirable {
    /// @notice Retrieves the current expiration period for enrollments or registrations.
    function getExpirationPeriod() external view returns (uint256);

    /// @notice Sets a new expiration period for an enrollment or registration.
    /// @param period The new expiration period, in seconds.
    function setExpirationPeriod(uint256 period) external;
}
