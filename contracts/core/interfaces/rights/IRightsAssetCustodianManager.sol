// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IRightsAssetCustodianManager
/// @notice Interface for managing custodian assignment priorities, redundancy limits, and weight calculations.
interface IRightsAssetCustodianManager {
    /// @notice Sets a custom priority value for a specific custodian assigned to the caller.
    /// @dev Influences the weighting in the balancing algorithm used to select custodians.
    /// @param custodian The custodian whose priority is being set.
    /// @param priority The priority value to assign. Must be >= 1.
    function setPriority(address custodian, uint256 priority) external;

    /// @notice Sets the maximum allowed number of custodians per holder.
    /// @param value The new maximum redundancy value.
    function setMaxAllowedRedundancy(uint256 value) external;

    /// @notice Returns the maximum allowed number of custodians per holder.
    /// @return The maximum redundancy value.
    function getMaxAllowedRedundancy() external view returns (uint256);

    /// @notice Retrieves the priority level associated with a specific custodian and holder.
    /// @param custodian The address of the custodian whose priority is being queried.
    /// @param holder The address of the holder associated with the custodian.
    /// @return The priority level as a uint256 value.
    function getPriority(address custodian, address holder) external view returns (uint256);

    /// @notice Returns a custodian selected by a probabilistic balancing algorithm.
    /// @dev The selection is based on priority, demand and economic weight (balance).
    /// @param holder The address of the asset holder requesting a custodian.
    /// @param currency The currency used to evaluate the custodian's balance.
    /// @return The selected custodian address.
    function getCustodian(address holder, address currency) external view returns (address);

    /// @notice Calculates the weighted score of a custodian for a specific holder and currency.
    /// @dev Used to externally query the score that influences custodian selection.
    /// @param custodian The address of the custodian.
    /// @param holder The address of the rights holder.
    /// @param currency The token used to evaluate economic backing.
    /// @return The computed weight used in the balancing algorithm.
    function getWeight(address custodian, address holder, address currency) external view returns (uint256);

    /// @notice Retrieves the total number of holders assigned to a custodian.
    /// @dev Represents the current load (demand) of a custodian in terms of assignments.
    /// @param custodian The custodian address to query.
    /// @return The number of holders currently assigned to the custodian.
    function getDemand(address custodian) external view returns (uint256);
}
