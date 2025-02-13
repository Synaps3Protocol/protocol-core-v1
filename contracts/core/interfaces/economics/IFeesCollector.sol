// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IFeesCollector
/// @notice Interface for collecting and disbursing protocol fees.
/// @dev This interface defines the mechanism for transferring collected fees to the treasury.
interface IFeesCollector {
    /// @notice Disburses funds from the contract to the treasury.
    /// @param currency The address of the ERC20 token to disburse tokens.
    function disburse(address currency) external returns (uint256);
}
