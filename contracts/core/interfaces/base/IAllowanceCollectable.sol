// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IAllowanceCollectable
/// @notice Interface for collecting funds in a ledger-based system.
interface IAllowanceCollectable {
    /// @notice Emitted when approved funds are successfully collected by a recipient.
    /// @dev Indicates that a specified amount of previously approved funds has been collected by the recipient.
    /// @param from The address of the account from which the funds are collected.
    /// @param to The address of the account that collected the approved funds.
    /// @param amount The amount of funds collected.
    /// @param currency The address of the currency in which the funds are collected.
    event FundsCollected(address indexed from, address indexed to, uint256 amount, address indexed currency);

    /// @notice Error emitted when attempting to collect funds that are not approved or insufficient.
    /// @dev Prevents collection of funds that do not meet the required criteria.
    error NoFundsToCollect();

    /// @notice Collects a specific amount of previously approved funds.
    /// @param from The address of the account from which the approved funds are being collected.
    /// @param amount The amount of funds to collect.
    /// @param currency The address of the ERC20 token to collect. Use `address(0)` for native tokens.
    function collect(address from, uint256 amount, address currency) external returns (uint256);
}
