// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IBalanceOperator } from "@synaps3/core/interfaces/base/IBalanceOperator.sol";
import { IAllowanceOperator } from "@synaps3/core/interfaces/base/IAllowanceOperator.sol";
import { ILockOperator } from "@synaps3/core/interfaces/base/ILockOperator.sol";

/// @title ILedgerVault
/// @notice Interface for managing locked funds and their operations.
/// @dev Extends IBalanceOperator for managing user balances in a vault-like system.
interface ILedgerVault is IBalanceOperator, IAllowanceOperator, ILockOperator {
    /// @notice Allows a currency to be used within the ledger operations.
    /// @param currency The address of the currency to allow. Use address(0) for the native coin.
    function allowCurrency(address currency) external;

    /// @notice Blocks a currency from being used within the ledger operations.
    /// @param currency The address of the currency to block. Use address(0) for the native coin.
    function blockCurrency(address currency) external;

    /// @notice Returns whether a currency is approved for ledger operations.
    /// @param currency The address of the currency to verify.
    function isCurrencyAllowed(address currency) external view returns (bool);
}
