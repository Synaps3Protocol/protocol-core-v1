// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IRightsAssetCustodianVerifiable
/// @notice Interface for verifying custodian assignments and querying custody-related data.
/// @dev Includes read-access functions used in balancing and audit operations.
interface IRightsAssetCustodianVerifiable {
    /// @notice Checks whether a custodian is currently assigned to a holder.
    /// @dev Returns true only if the custodian is active and listed for the specified holder.
    /// @param holder The address of the asset rights holder.
    /// @param custodian The address of the custodian to verify.
    /// @return True if `custodian` is valid and assigned to `holder`, false otherwise.
    function isCustodian(address holder, address custodian) external view returns (bool);

    /// @notice Returns a custodian selected by a probabilistic balancing algorithm.
    /// @dev The selection is based on priority, demand and economic weight (balance).
    /// @param holder The address of the asset holder requesting a custodian.
    /// @param currency The currency used to evaluate the custodian's balance.
    /// @return The selected custodian address.
    function getBalancedCustodian(address holder, address currency) external view returns (address);

    /// @notice Retrieves the total number of holders assigned to a custodian.
    /// @dev Represents the current load (demand) of a custodian in terms of assignments.
    /// @param custodian The custodian address to query.
    /// @return The number of holders currently assigned to the custodian.
    function getCustodyCount(address custodian) external view returns (uint256);

    /// @notice Calculates the weighted score of a custodian for a specific holder and currency.
    /// @dev Used to externally query the score that influences custodian selection.
    /// @param holder The address of the rights holder.
    /// @param custodian The address of the custodian.
    /// @param currency The token used to evaluate economic backing.
    /// @return The computed weight used in the balancing algorithm.
    function calcWeight(address holder, address custodian, address currency) external view returns (uint256);
}
