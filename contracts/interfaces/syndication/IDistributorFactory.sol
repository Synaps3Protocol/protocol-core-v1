// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Interface for the DistributorFactory contract.
/// @notice Allows interaction with the DistributorFactory contract to create new distributors.
interface IDistributorFactory {
    /// @notice Function to pause the contract, preventing the creation of new distributors.
    /// @dev Can only be called by the owner of the contract.
    function pause() external;

    /// @notice Function to unpause the contract, allowing the creation of new distributors.
    /// @dev Can only be called by the owner of the contract.
    function unpause() external;

    /// @notice Function to create a new distributor contract.
    /// @dev The contract must not be paused to call this function.
    /// @param endpoint The endpoint associated with the new distributor.
    /// @return The address of the newly created distributor contract.
    function create(string calldata endpoint) external returns (address);
}
