// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IAllowanceRevokable
/// @notice Interface for revoking approved funds in a ledger-based system.
interface IAllowanceRevokable {
    /// @notice Emitted when an approval is revoked by the approver.
    /// @param from The address of the approver.
    /// @param to The address of the recipient whose approval was revoked.
    /// @param amount The amount of funds revoked.
    /// @param currency The address of the currency for which the approval was revoked.
    event FundsRevoked(address indexed from, address indexed to, uint256 amount, address indexed currency);

    /// @notice Error emitted when there are no approved funds to revoke.
    /// @dev Ensures that revoke operations cannot exceed the current approved amount.
    error NoFundsToRevoke();

    /// @notice Revokes a specified amount of approved funds from the caller's balance for a recipient.
    /// @dev Allows partial or full revocation of existing approvals for a recipient and currency pair.
    /// @param to The address of the recipient whose approval is being revoked.
    /// @param amount The amount of funds to revoke from the existing approval.
    /// @param currency The address of the ERC20 token associated with the approval. Use `address(0)` for native tokens.
    /// @return The amount of funds that were successfully revoked.
    function revoke(address to, uint256 amount, address currency) external returns (uint256);
}
