// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IBalanceDepositor Interface
/// @notice This interface defines the functionality for depositing funds into the contract.
interface IBalanceDepositor {
    /// @notice Emitted when funds are successfully deposited into the pool.
    /// @param recipient The address of the account credited with the deposit.
    /// @param origin The address sending the deposit funds.
    /// @param amount The amount of currency deposited.
    /// @param currency The address of the ERC20 token deposited.
    event FundsDeposited(address indexed recipient, address indexed origin, uint256 amount, address currency);

    /// @notice Deposits a specified amount of currency into the pool for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address recipient, uint256 amount, address currency) external returns (uint256);
}
