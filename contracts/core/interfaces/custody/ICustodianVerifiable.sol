// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title ICustodianVerifiable
/// @notice This interface defines the method for checking if an entity is active.
interface ICustodianVerifiable {
    /// @notice Checks if the entity associated with the given identifier is active.
    /// @param custodian The address of the custodian to check status.
    function isActive(address custodian) external view returns (bool);

    /// @notice Checks if the entity associated with the given identifier is waiting approval.
    /// @param custodian The address of the custodian to check status.
    function isWaiting(address custodian) external view returns (bool);

    /// @notice Checks if the entity associated with the given identifier is blocked approval.
    /// @param custodian The address of the custodian to check status.
    function isBlocked(address custodian) external view returns (bool);
}
