// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { LedgerUpgradeable } from "@synaps3/core/primitives/upgradeable/LedgerUpgradeable.sol";

import { IBalanceOperator } from "@synaps3/core/interfaces/base/IBalanceOperator.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title BalanceOperatorUpgradeable
/// @dev Abstract contract for managing deposits and withdrawals with ledger tracking capabilities.
///      Provides core functionalities to handle funds in an upgradeable system.
///      This contract integrates with the ledger system to record balances and transactions.
abstract contract BalanceOperatorUpgradeable is Initializable, LedgerUpgradeable, IBalanceOperator {
    using FinancialOps for address;

    /// @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    /// This is the method to initialize this contract and any other extended contracts.
    function __BalanceOperator_init() internal onlyInitializing {
        __Ledger_init();
    }

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    /// This is the method to initialize this contract as standalone.
    function __BalanceOperator_init_unchained() internal onlyInitializing {}

    /// @notice Returns the general's balance for the specified currency.
    /// @dev The function checks the balance for both native and ERC-20 tokens.
    /// @param currency The address of the currency to check the balance of.
    function getBalance(address currency) public view returns (uint256) {
        return address(this).balanceOf(currency);
    }

    /// @notice Deposits a specified amount of currency into the treasury for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function _deposit(address recipient, uint256 amount, address currency) internal returns (uint256) {
        uint256 confirmed = msg.sender.safeDeposit(amount, currency);
        _sumLedgerEntry(recipient, confirmed, currency);
        return confirmed;
    }

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @dev This function withdraws funds from the caller's balance and transfers them to the recipient.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function _withdraw(address recipient, uint256 amount, address currency) internal returns (uint256) {
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToWithdraw();
        _subLedgerEntry(msg.sender, amount, currency);
        recipient.transfer(amount, currency);
        return amount;
    }

    /// @notice Transfers tokens internally within the ledger from the caller to a specified recipient.
    /// @dev This function facilitates an internal ledger transfer without an external token movement.
    ///      Ensures the caller has sufficient funds and updates the ledger for both accounts.
    /// @param recipient The address of the account to credit with the transfer.
    /// @param amount The amount of tokens to transfer.
    /// @param currency The address of the currency to transfer. Use `address(0)` for the native coin.
    function _transfer(address recipient, uint256 amount, address currency) internal returns (uint256) {
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToTransfer();
        _subLedgerEntry(msg.sender, amount, currency);
        _sumLedgerEntry(recipient, amount, currency);
        return amount;
    }
}
