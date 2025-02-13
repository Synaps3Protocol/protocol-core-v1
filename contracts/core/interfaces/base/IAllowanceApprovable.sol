// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IAllowanceApprovable
/// @notice Interface for approving and managing approved funds in a ledger-based system.
interface IAllowanceApprovable {
    /// @notice Emitted when a specific amount of funds is approved for a recipient.
    /// @param from The address of the approver.
    /// @param to The address of the recipient.
    /// @param amount The amount of funds approved.
    /// @param currency The address of the currency approved.
    event FundsApproved(address indexed from, address indexed to, uint256 amount, address indexed currency);

    /// @notice Error emitted when there are no available funds to approve.
    /// @dev Triggered when the approval amount exceeds the available balance.
    error NoFundsToApprove();

    /// @notice Approves a specific amount of funds from the caller's balance for a recipient.
    /// @param to The address of the recipient for whom the funds are being approved.
    /// @param amount The amount of funds to approve.
    /// @param currency The address of the ERC20 token to approve. Use `address(0)` for native tokens.
    /// @return The amount of funds that were successfully approved.
    function approve(address to, uint256 amount, address currency) external returns (uint256);
}
