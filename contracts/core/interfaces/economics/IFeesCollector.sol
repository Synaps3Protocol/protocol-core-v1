// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IFeesCollector {
    /// @notice Disburses funds from the contract to the treasury.
    /// @param currency The address of the ERC20 token to disburse tokens.
    function disburse(address currency) external returns (uint256);
}
