// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { LedgerUpgradeable } from "@synaps3/core/primitives/upgradeable/LedgerUpgradeable.sol";
import { IBalanceOperator } from "@synaps3/core/interfaces/base/IBalanceOperator.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

/// @title BalanceOperatorUpgradeable
/// @dev Abstract contract for managing deposits and withdrawals with ledger tracking capabilities.
///      Provides core functionalities to handle funds in an upgradeable system.
///      This contract integrates with the ledger system to record balances and transactions.
abstract contract BalanceOperatorUpgradeable is
    Initializable,
    LedgerUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    IBalanceOperator
{
    using FinancialOps for address;

    /// @custom:storage-location erc7201:balanceoperatorupgradeable
    struct BalanceOperatorStorage {
        /// @dev Holds the relation between approved funds the currency and amount
        mapping(bytes32 => mapping(address => uint256)) _approved;
    }

    /// @dev Storage slot for BalanceOperatorUpgradeable, calculated using a unique namespace to avoid conflicts.
    /// The `BALANCE_OPERATOR_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant BALANCE_OPERATOR_SLOT = 0xa8707513830ffbd3c47e0c83d1f5f0270db240ae37bb1f9a13f077f85b949c00;

    /// @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    /// This is the method to initialize this contract and any other extended contracts.
    function __BalanceOperator_init() internal onlyInitializing {
        __Ledger_init();
        __ReentrancyGuardTransient_init();
    }

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    /// This is the method to initialize this contract as standalone.
    function __BalanceOperator_init_unchained() internal onlyInitializing {}

    /// @notice Returns the general's balance for the specified currency.
    /// @dev The function checks the balance for both native and ERC-20 tokens.
    /// @param currency The address of the currency to check the balance of.
    function getBalance(address currency) external view returns (uint256) {
        return address(this).balanceOf(currency);
    }

    /// @notice Deposits a specified amount of currency into the contract for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(
        address recipient,
        uint256 amount,
        address currency
    ) public virtual onlyValidOperation(recipient, amount) returns (uint256) {
        uint256 confirmed = msg.sender.safeDeposit(amount, currency);
        _sumLedgerEntry(recipient, confirmed, currency);
        emit FundsDeposited(recipient, msg.sender, confirmed, currency);
        return confirmed;
    }

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(
        address recipient,
        uint256 amount,
        address currency
    ) public virtual onlyValidOperation(recipient, amount) nonReentrant returns (uint256) {
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToWithdraw();
        _subLedgerEntry(msg.sender, amount, currency);
        recipient.transfer(amount, currency); // transfer fund to recipient
        emit FundsWithdrawn(recipient, msg.sender, amount, currency);
        return amount;
    }

    /// @notice Transfers tokens internally within the ledger from the caller to a specified recipient.
    /// @param recipient The address of the account to credit with the transfer.
    /// @param amount The amount of tokens to transfer.
    /// @param currency The address of the currency to transfer. Use `address(0)` for the native coin.
    function transfer(
        address recipient,
        uint256 amount,
        address currency
    ) public virtual onlyValidOperation(recipient, amount) returns (uint256) {
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToTransfer();
        _subLedgerEntry(msg.sender, amount, currency);
        _sumLedgerEntry(recipient, amount, currency);
        emit FundsTransferred(recipient, msg.sender, amount, currency);
        return amount;
    }

    /// @notice Internal function to get the balance operator storage.
    /// @dev Uses assembly to retrieve the storage at the pre-calculated storage slot.
    function _getBalanceOperatorStorage() private pure returns (BalanceOperatorStorage storage $) {
        assembly {
            $.slot := BALANCE_OPERATOR_SLOT
        }
    }
}
