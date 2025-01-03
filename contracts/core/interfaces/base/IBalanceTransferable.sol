// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IBalanceTransferable Interface
/// @notice This interface defines the functionality for transferring balances between accounts.
interface IBalanceTransferable {
    /// @notice Error indicating that there are no funds available to transfer.
    /// @dev This error is triggered when a transfer is attempted but the sender has insufficient funds or no balance.
    error NoFundsToTransfer();

    /// @notice Emitted when funds are successfully transferred between accounts.
    /// @param recipient The address of the account receiving the funds.
    /// @param origin The address of the account initiating the transfer.
    /// @param amount The amount of currency transferred.
    /// @param currency The address of the ERC20 token transferred. Use `address(0)` for native tokens.
    event FundsTransferred(address indexed recipient, address indexed origin, uint256 amount, address currency);

    /// @notice Transfers a specified amount of currency from the caller's balance to a given recipient.
    /// @dev Ensures the caller has sufficient balance before performing the transfer. Updates the ledger accordingly.
    /// @param recipient The address of the account to credit with the transfer.
    /// @param amount The amount of currency to transfer.
    /// @param currency The address of the ERC20 token to transfer. Use `address(0)` for native tokens.
    function transfer(address recipient, uint256 amount, address currency) external returns (uint256);
}
