// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.8.24/natspec-format.html
pragma solidity 0.8.26;
import { ILedgerVerifiable } from "contracts/interfaces/ILedgerVerifiable.sol";

/// @title Ledger
/// @notice Abstract contract to manage and store ledger entries for different accounts and currencies.
/// @dev This contract defines internal functions to manipulate ledger balances and retrieve account data.
abstract contract Ledger is ILedgerVerifiable {
    // Mapping to store balances per account and currency.
    mapping(address => mapping(address => uint256)) private ledger;

    /// @notice Retrieves the registered currency balance for the specified account.
    /// @param account The address of the account to retrieve the balance for.
    /// @param currency The address of the currency to retrieve the balance for.
    function getLedgerBalance(address account, address currency) public view returns (uint256) {
        return ledger[account][currency]; // Return the ledger balance for the account and currency.
    }

    /// @notice Internal function to store the currency fees for an account.
    /// @param account The address of the account for which the amount is being set.
    /// @param amount The amount to register for the account.
    /// @param currency The address of the currency being registered.
    /// @dev This function overwrites any previous balance for the account in the given currency.
    function _setLedgerEntry(address account, uint256 amount, address currency) internal {
        ledger[account][currency] = amount;
    }

    /// @notice Internal function to accumulate currency fees for an account.
    /// @param account The address of the account for which the amount is being added.
    /// @param amount The amount to add to the account's balance.
    /// @param currency The address of the currency being added.
    /// @dev This function increases the existing balance of the account for the specified currency.
    function _sumLedgerEntry(address account, uint256 amount, address currency) internal {
        ledger[account][currency] += amount;
    }

    /// @notice Internal function to subtract currency fees for an account.
    /// @param account The address of the account for which the amount is being subtracted.
    /// @param amount The amount to subtract from the account's balance.
    /// @param currency The address of the currency being subtracted.
    /// @dev This function decreases the existing balance of the account for the specified currency.
    function _subLedgerEntry(address account, uint256 amount, address currency) internal {
        ledger[account][currency] -= amount;
    }
}
