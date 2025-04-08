// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IBalanceDepositor } from "@synaps3/core/interfaces/base/IBalanceDepositor.sol";
import { IBalanceWithdrawable } from "@synaps3/core/interfaces/base/IBalanceWithdrawable.sol";
import { IBalanceTransferable } from "@synaps3/core/interfaces/base/IBalanceTransferable.sol";
import { IBalanceVerifiable } from "@synaps3/core/interfaces/base/IBalanceVerifiable.sol";

/// @title IBalanceOperator Interface
/// @notice Combines functionalities for verifying, depositing, withdrawing, and transferring balances.
/// @dev This interface aggregates multiple interfaces to standardize balance-related operations.
/// @dev The `IBalanceOperator` interface extends multiple interfaces to provide a comprehensive suite of
/// balance-related operations, including deposit, withdrawal, transfer, reserve, and balance verification.
interface IBalanceOperator is IBalanceDepositor, IBalanceWithdrawable, IBalanceTransferable, IBalanceVerifiable {

}
