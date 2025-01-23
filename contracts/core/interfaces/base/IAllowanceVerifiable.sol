// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IAllowanceVerifiable
/// @notice Interface for verifying approved funds in a ledger-based system.
interface IAllowanceVerifiable {
    /// @notice Retrieves the approved balance for a specific relationship and currency.
    /// @param from The address of the account that granted the approval.
    /// @param to The address of the recipient for whom the approval was made.
    /// @param currency The address of the currency approved. Use `address(0)` for native tokens.
    /// @return The amount of funds approved by `from` for `to` in the specified `currency`.
    function getApprovedAmount(address from, address to, address currency) external view returns (uint256);
}
