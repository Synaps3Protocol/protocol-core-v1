// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IBalanceOperator } from "@synaps3/core/interfaces/base/IBalanceOperator.sol";
import { IAllowanceOperator } from "@synaps3/core/interfaces/base/IAllowanceOperator.sol";

/// @title ILedgerVault
/// @notice Interface for managing locked funds and their operations.
/// @dev Extends IBalanceOperator for managing user balances in a vault-like system.
interface ILedgerVault is IBalanceOperator, IAllowanceOperator {
    /// @notice Locks a specific amount of funds for a given account.
    /// @dev The funds are immobilized and cannot be withdrawn or transferred until released or claimed.
    /// @param account The address of the account for which the funds will be locked.
    /// @param amount The amount of funds to lock.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function lock(address account, uint256 amount, address currency) external returns (uint256);

    /// @notice Claims a specific amount of locked funds on behalf of a claimer.
    /// @dev The claimer is authorized to withdraw or process the funds from the account.
    /// @param account The address of the account whose funds are being claimed.
    /// @param amount The amount of funds to claim.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function claim(address account, uint256 amount, address currency) external returns (uint256);

    /// @notice Release a specific amount of funds from locked pool.
    /// @param account The address of the account for which the funds will be released.
    /// @param amount The amount of funds to release.
    /// @param currency The currency to associate release with. Use address(0) for the native coin.
    function release(address account, uint256 amount, address currency) external returns (uint256);
}
