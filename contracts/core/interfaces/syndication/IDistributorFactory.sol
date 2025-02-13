// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title Interface for the DistributorFactory contract.
/// @notice Allows interaction with the DistributorFactory contract to create new distributors.
interface IDistributorFactory {
    /// @notice Function to create a new distributor contract.
    /// @dev The contract must not be paused to call this function.
    /// @param endpoint The endpoint associated with the new distributor.
    /// @return The address of the newly created distributor contract.
    function create(string calldata endpoint) external returns (address);

    /// @notice Retrieves the creator of a given distributor contract.
    /// @param distributor The address of the distributor contract.
    /// @return The address of the entity that created the distributor.
    function getCreator(address distributor) external view returns (address);
}
