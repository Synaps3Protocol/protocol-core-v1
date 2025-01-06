// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IBalanceReservable
/// @notice Interface for reserving and collecting funds in a ledger-based system.
/// @dev This interface defines the standard methods for managing fund reservations and collections
///      within a ledger. Implementing contracts are expected to handle the actual storage and logic
///      of reservations while adhering to this interface.
interface IBalanceReservable {
    /// @notice Emitted when funds are reserved between two accounts.
    /// @dev Indicates that a specified amount of currency has been reserved from one account to another.
    /// @param from The address of the account from which the funds are reserved.
    /// @param to The address of the account for which the funds are reserved.
    /// @param amount The amount of funds reserved.
    /// @param currency The address of the currency in which the funds are reserved.
    event FundsReserved(address indexed from, address indexed to, uint256 amount, address indexed currency);

    /// @notice Emitted when reserved funds are successfully collected by a recipient.
    /// @dev Indicates that a specified amount of previously reserved funds has been collected by the recipient.
    /// @param from The address of the account from which the funds are collected.
    /// @param to The address of the account that collected the reserved funds.
    /// @param amount The amount of funds collected.
    /// @param currency The address of the currency in which the funds are collected.
    event FundsCollected(address indexed from, address indexed to, uint256 amount, address indexed currency);

    /// @notice Thrown when there are no available funds to reserve.
    /// @dev This error occurs if an account attempts to reserve more funds than available.
    error NoFundsToReserve();

    /// @notice Thrown when there are no reserved funds available to release.
    /// @dev This error occurs if an operator tries to collected funds that are not reserved or insufficient.
    error NoFundsToCollect();

    /// @notice Reserves a specific amount of funds from the caller's balance for a recipient.
    /// @param to The address of the recipient for whom the funds are being reserved.
    /// @param amount The amount of funds to reserve.
    /// @param currency The address of the ERC20 token to reserve. Use `address(0)` for native tokens.
    function reserve(address to, uint256 amount, address currency) external returns (uint256);

    /// @notice Collects a specific amount of previously reserved funds.
    /// @param from The address of the account from which the reserved funds are being collected.
    /// @param amount The amount of funds to collect.
    /// @param currency The address of the ERC20 token to collect. Use `address(0)` for native tokens.
    function collect(address from, uint256 amount, address currency) external returns (uint256);
}
