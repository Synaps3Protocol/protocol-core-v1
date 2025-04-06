// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IBalanceWithdrawable Interface
/// @notice This interface defines the functionality for withdrawing funds from the contract to a specified address.
interface IBalanceWithdrawable {
    /// @notice Emitted when funds are withdrawn from the contract.
    /// @param recipient The address receiving the withdrawn funds.
    /// @param origin The address sending the withdrawn funds.
    /// @param amount The amount of funds being withdrawn.
    /// @param currency The currency used for the withdrawal.
    event FundsWithdrawn(address indexed recipient, address indexed origin, uint256 amount, address currency);

    /// @notice Error emitted when there are insufficient funds for withdrawal.
    /// @dev Occurs if the caller attempts to withdraw more than their available balance.
    error NoFundsToWithdraw();

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external returns (uint256);
}
