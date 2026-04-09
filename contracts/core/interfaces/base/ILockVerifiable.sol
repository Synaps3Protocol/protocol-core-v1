// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title ILockVerifiable
/// @notice Exposes read-only access to locked balances.
interface ILockVerifiable {
    /// @notice Returns the locked balance for an account and currency.
    /// @param account The address whose locked funds are being queried.
    /// @param currency The currency associated with the locked funds.
    /// @return The amount of locked funds.
    function getLockedBalance(address account, address currency) external view returns (uint256);
}
