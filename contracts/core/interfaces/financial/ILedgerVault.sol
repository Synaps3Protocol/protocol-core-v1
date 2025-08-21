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

}
