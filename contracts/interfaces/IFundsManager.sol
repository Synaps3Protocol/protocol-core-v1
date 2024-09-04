// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IFundsManager Interface
/// @notice This interface defines the functionality for withdrawing funds from the contract to a specified address.
/// @dev This interface is intended to be implemented by contracts that need to allow secure withdrawal of funds
///      to specified recipients. The `withdraw` function should be protected to ensure that only the contract owner
///      or an authorized entity can initiate a withdrawal.
interface IFundsManager {
    /// @notice Withdraws erc20 funds from the contract to a specified recipient's address.
    /// @param amount The amount of funds to withdraw.
    /// @param currency The currency to associate fees with. 
    function withdraw(uint256 amount, address currency) external;
    
    // function getBalance
}