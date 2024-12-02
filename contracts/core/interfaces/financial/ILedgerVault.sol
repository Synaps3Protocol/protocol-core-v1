// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IBalanceWithdrawable } from "@synaps3/core/interfaces/IBalanceWithdrawable.sol";

interface ILedgerVault is IBalanceWithdrawable {
    /// @notice Emitted when funds are successfully deposited into the treasury.
    /// @param recipient The address of the account credited with the deposit.
    /// @param amount The amount of currency deposited.
    /// @param currency The address of the ERC20 token deposited.
    event FundsDeposited(address indexed recipient, uint256 amount, address currency);

    /// @notice Deposits a specified amount of currency into the treasury for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address recipient, uint256 amount, address currency) external;

}
