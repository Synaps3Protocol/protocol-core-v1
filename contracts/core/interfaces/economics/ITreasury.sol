// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IBalanceWithdrawable } from "contracts/core/interfaces/IBalanceWithdrawable.sol";

/// @title ITreasury Interface
/// @notice Defines the standard functions for a Treasury contract.
interface ITreasury is IBalanceWithdrawable {
    /// @notice Emitted when funds are successfully deposited into the treasury.
    /// @param recipient The address of the account credited with the deposit.
    /// @param amount The amount of currency deposited.
    /// @param currency The address of the ERC20 token deposited.
    event FundsDeposited(address indexed recipient, uint256 amount, address currency);

    /// @notice Emitted when funds are disbursed to the treasury from a collector.
    /// @param collector The address of the collector disbursing the funds.
    /// @param amount The amount of tokens that were disbursed.
    /// @param currency The address of the ERC20 token contract for the currency disbursed.
    event FundsCollected(address indexed collector, uint256 amount, address currency);

    /// @notice Deposits a specified amount of currency into the treasury for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address recipient, uint256 amount, address currency) external;

    // /// @notice Batch deposit multiple currency amounts into the treasury for multiple recipients.
    // /// @param deposits An array of Deposit structs containing recipient, amount, and currency for each deposit.
    // /// @return The total amount of currency deposited across all batch deposits.
    // function batchDeposit(..) external returns (uint256);

    /// @notice Collects all accrued fees for a specified currency from a list of authorized collectors.
    /// @dev This function aggregates the fees from specified collectors and prepares them for distribution.
    /// @param collectors The list of addresses authorized to collect fees on behalf of the treasury.
    /// @param currency The address of the ERC20 token to collect fees.
    function collectFees(address[] calldata collectors, address currency) external;
}
