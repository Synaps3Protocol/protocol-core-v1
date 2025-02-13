// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IDistributorVerifiable
/// @notice This interface defines the method for checking if an entity is active.
interface IDistributorVerifiable {
    /// @notice Checks if the entity associated with the given identifier is active.
    /// @param distributor The address of the distributor to check status.
    function isActive(address distributor) external view returns (bool);

    /// @notice Checks if the entity associated with the given identifier is waiting approval.
    /// @param distributor The address of the distributor to check status.
    function isWaiting(address distributor) external view returns (bool);

    /// @notice Checks if the entity associated with the given identifier is blocked approval.
    /// @param distributor The address of the distributor to check status.
    function isBlocked(address distributor) external view returns (bool);
}
