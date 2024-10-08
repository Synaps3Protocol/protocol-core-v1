// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Syndicatable Verifiable Interface
/// @notice This interface defines the method for checking if an entity is active.
interface ISyndicatableVerifiable {
    /// @notice Checks if the entity associated with the given identifier is active.
    /// @param distributor The address of the distributor to check status.
    function isActive(address distributor) external returns (bool);

    /// @notice Checks if the entity associated with the given identifier is waiting approval.
    /// @param distributor The address of the distributor to check status.
    function isWaiting(address distributor) external returns (bool);

    /// @notice Checks if the entity associated with the given identifier is blocked approval.
    /// @param distributor The address of the distributor to check status.
    function isBlocked(address distributor) external returns (bool);
}
