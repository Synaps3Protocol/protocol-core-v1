// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IBalanceOperator Interface
/// @notice Combines functionalities for verifying, depositing, withdrawing, and transferring balances.
/// @dev This interface aggregates multiple interfaces to standardize balance-related operations.
import { IBalanceDepositor } from "@synaps3/core/interfaces/base/IBalanceDepositor.sol";
import { IBalanceWithdrawable } from "@synaps3/core/interfaces/base/IBalanceWithdrawable.sol";
import { IBalanceTransferable } from "@synaps3/core/interfaces/base/IBalanceTransferable.sol";
import { IBalanceVerifiable } from "@synaps3/core/interfaces/base/IBalanceVerifiable.sol";
import { IBalanceReservable } from "@synaps3/core/interfaces/base/IBalanceReservable.sol";
import { ILedgerVerifiable } from "@synaps3/core/interfaces/base/ILedgerVerifiable.sol";

/// @dev The `IBalanceOperator` interface extends multiple interfaces to provide a comprehensive suite of
/// balance-related operations, including deposit, withdrawal, transfer, reserve, and balance verification.
interface IBalanceOperator is
    IBalanceWithdrawable,
    IBalanceDepositor,
    IBalanceTransferable,
    IBalanceReservable,
    IBalanceVerifiable,
    ILedgerVerifiable
{}
