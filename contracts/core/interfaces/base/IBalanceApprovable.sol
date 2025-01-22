// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IBalanceApprovable
/// @notice Interface for approving and managing approved funds in a ledger-based system.
interface IBalanceApprovable {
    /// @notice Emitted when a specific amount of funds is approved for a recipient.
    /// @param from The address of the approver.
    /// @param to The address of the recipient.
    /// @param amount The amount of funds approved.
    /// @param currency The address of the currency approved.
    event FundsApproved(address indexed from, address indexed to, uint256 amount, address indexed currency);

    /// @notice Error emitted when there are no available funds to approve.
    /// @dev Triggered when the approval amount exceeds the available balance.
    error NoFundsToApprove();

    /// @notice Retrieves the approved balance for a specific relationship and currency.
    /// @param from The address of the account that granted the approval.
    /// @param to The address of the recipient for whom the approval was made.
    /// @param currency The address of the currency approved. Use `address(0)` for native tokens.
    /// @return The amount of funds approved by `from` for `to` in the specified `currency`.
    function getApprovedAmount(address from, address to, address currency) external view returns (uint256);

    /// @notice Approves a specific amount of funds from the caller's balance for a recipient.
    /// @param to The address of the recipient for whom the funds are being approved.
    /// @param amount The amount of funds to approve.
    /// @param currency The address of the ERC20 token to approve. Use `address(0)` for native tokens.
    /// @return The amount of funds that were successfully approved.
    function approve(address to, uint256 amount, address currency) external returns (uint256);
}
