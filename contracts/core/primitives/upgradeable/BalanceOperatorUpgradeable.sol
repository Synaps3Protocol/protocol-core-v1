// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { LedgerUpgradeable } from "@synaps3/core/primitives/upgradeable/LedgerUpgradeable.sol";

import { IBalanceOperator } from "@synaps3/core/interfaces/base/IBalanceOperator.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

/// @title BalanceOperatorUpgradeable
/// @dev Abstract contract for managing deposits and withdrawals with ledger tracking capabilities.
///      Provides core functionalities to handle funds in an upgradeable system.
///      This contract integrates with the ledger system to record balances and transactions.
abstract contract BalanceOperatorUpgradeable is Initializable, LedgerUpgradeable, IBalanceOperator {
    using FinancialOps for address;

    /// @custom:storage-location erc7201:balanceoperatorupgradeable
    struct BalanceOperatorStorage {
        /// @dev Holds the relation between a reserved funds the currency and amount
        mapping(bytes32 => mapping(address => uint256)) _reserved;
    }

    /// @dev Storage slot for BalanceOperatorUpgradeable, calculated using a unique namespace to avoid conflicts.
    /// The `BALANCE_OPERATOR_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant BALANCE_OPERATOR_SLOT = 0xa8707513830ffbd3c47e0c83d1f5f0270db240ae37bb1f9a13f077f85b949c00;

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

    /// @notice Reserves a specific amount of funds from the caller's balance for a recipient.
    /// @param to The address of the recipient for whom the funds are being reserved.
    /// @param amount The amount of funds to reserve.
    /// @param currency The address of the ERC20 token to reserve. Use `address(0)` for native tokens.
    function _reserve(address to, uint256 amount, address currency) internal returns (uint256) {
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToReserve();
        _subLedgerEntry(msg.sender, amount, currency);
        _sumReservedAmount(msg.sender, to, amount, currency);
        return amount;
    }

    /// @notice Collects a specific amount of previously reserved funds.
    /// @param from The address of the account from which the reserved funds are being collected.
    /// @param amount The amount of funds to collect.
    /// @param currency The address of the ERC20 token to collect. Use `address(0)` for native tokens.
    function _collect(address from, uint256 amount, address currency) internal returns (uint256) {
        if (_getReservedAmount(from, msg.sender, currency) < amount) revert NoFundsToCollect();
        _subReservedAmount(from, msg.sender, amount, currency);
        _sumLedgerEntry(msg.sender, amount, currency);
        return amount;
    }

    /// @notice Reduces the reserved funds for a specific relationship and currency.
    /// @dev Deducts the specified `amount` from the `_reserved` mapping for the given `from` and `to` relationship and `currency`.
    /// @param from The address of the account from which the funds were reserved.
    /// @param to The address of the account for which the funds were reserved.
    /// @param amount The amount to subtract from the reserved balance.
    /// @param currency The address of the currency being reduced.
    function _subReservedAmount(address from, address to, uint256 amount, address currency) private {
        BalanceOperatorStorage storage $ = _getBalanceOperatorStorage();
        bytes32 relation = _computeComposedKey(from, to);
        $._reserved[relation][currency] -= amount;
    }

    /// @notice Increases the reserved funds for a specific relationship and currency.
    /// @dev Adds the specified `amount` to the `_reserved` mapping for the given `from` and `to` relationship and `currency`.
    /// @param from The address of the account from which the funds are reserved.
    /// @param to The address of the account for which the funds are reserved.
    /// @param amount The amount to add to the reserved balance.
    /// @param currency The address of the currency being increased.
    function _sumReservedAmount(address from, address to, uint256 amount, address currency) private {
        BalanceOperatorStorage storage $ = _getBalanceOperatorStorage();
        bytes32 relation = _computeComposedKey(from, to);
        $._reserved[relation][currency] += amount;
    }

    /// @notice Retrieves the reserved balance for a specific relationship and currency.
    /// @dev Returns the value stored in the `_reserved` mapping for the given `from` and `to` relationship and `currency`.
    /// @param from The address of the account from which the funds are reserved.
    /// @param to The address of the account for which the funds are reserved.
    /// @param currency The address of the currency to check the reserved balance for.
    /// @return The reserved balance for the specified relationship and currency.
    function _getReservedAmount(address from, address to, address currency) private view returns (uint256) {
        BalanceOperatorStorage storage $ = _getBalanceOperatorStorage();
        bytes32 relation = _computeComposedKey(from, to);
        return $._reserved[relation][currency];
    }

    /// @notice Computes a unique key by combining two addresses.
    /// @dev This key is used to map relationships between accounts.
    /// @param from The address of the user for whom the key is being generated.
    /// @param to Encoded data representing the context for the operation.
    /// @return A `bytes32` hash that uniquely identifies the context-account pair.
    function _computeComposedKey(address from, address to) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, to));
    }

    /// @notice Internal function to get the balance operator storage.
    /// @dev Uses assembly to retrieve the storage at the pre-calculated storage slot.
    function _getBalanceOperatorStorage() private pure returns (BalanceOperatorStorage storage $) {
        assembly {
            $.slot := BALANCE_OPERATOR_SLOT
        }
    }
}
