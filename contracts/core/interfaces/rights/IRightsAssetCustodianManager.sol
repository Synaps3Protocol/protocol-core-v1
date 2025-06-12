// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IRightsRedundancyManager
/// @notice Interface for managing redundancy limits for custodians.
interface IRightsAssetCustodianManager {
    /// @notice Sets a custom priority value for a specific custodian assigned to the caller.
    /// @dev Influences the weighting in the balancing algorithm used to select custodians.
    /// @param custodian The custodian whose priority is being set.
    /// @param priority The priority value to assign. Must be >= 1.
    function setPriority(address custodian, uint256 priority) external;

    /// @notice Returns the maximum allowed number of custodians per holder.
    /// @return The maximum redundancy value.
    function getMaxAllowedRedundancy() external view returns (uint256);

    /// @notice Sets the maximum allowed number of custodians per holder.
    /// @param value The new maximum redundancy value.
    function setMaxAllowedRedundancy(uint256 value) external;
}
