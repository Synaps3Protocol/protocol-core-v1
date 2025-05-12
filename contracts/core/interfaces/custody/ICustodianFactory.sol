// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title Interface for the CustodianFactory contract.
/// @notice Allows interaction with the CustodianFactory contract to create new custodians.
interface ICustodianFactory {
    /// @notice Function to create a new custodian contract.
    /// @dev The contract must not be paused to call this function.
    /// @param endpoint The endpoint associated with the new custodian.
    /// @return The address of the newly created custodian contract.
    function create(string calldata endpoint) external returns (address);

    /// @notice Retrieves the creator of a given custodian contract.
    /// @param custodian The address of the custodian contract.
    /// @return The address of the entity that created the custodian.
    function getCreator(address custodian) external view returns (address);

    /// @notice Checks whether a given custodian contract has been registered.
    /// @param custodian The address of the custodian contract to check.
    /// @return True if the custodian is registered; false otherwise.
    function isRegistered(address custodian) external view returns (bool);
}
