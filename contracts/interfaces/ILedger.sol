// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title ILedger Interface
/// @dev This interface provides functionality to track and retrieve account balances.
interface ILedger {
    /// @notice Retrieves the registered currency amount for the specified account.
    /// @param account The address of the account.
    /// @param currency The address of the currency to retrieve ledger amount (use address(0) for the native currency).
    function getLedgerBalance(address account, address currency) external view returns (uint256);
}
