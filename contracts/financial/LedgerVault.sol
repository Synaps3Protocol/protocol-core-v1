// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { AllowanceOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/AllowanceOperatorUpgradeable.sol";
import { LockOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/LockOperatorUpgradeable.sol";
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { BalanceOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";

import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

/// @title LedgerVault
/// @notice A vault contract designed to store, lock, release, and manage funds securely.
/// @dev This contract includes administrative methods (`restricted`) and general user methods.
///      Supports operations such as deposits, withdrawals, transfers, and locked funds management.
contract LedgerVault is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    AccessControlledUpgradeable,
    AllowanceOperatorUpgradeable,
    BalanceOperatorUpgradeable,
    LockOperatorUpgradeable,
    ILedgerVault
{
    /// @dev Tracks which currencies are approved for ledger operations.
    mapping(address => bool) private _approvedCurrencies;

    /// @notice Emitted when a currency approval state changes.
    /// @param currency The address of the currency whose approval status changed.
    /// @param allowed The new approval status.
    /// @param admin The admin that triggered the change.
    event CurrencyApprovalUpdated(address indexed currency, bool allowed, address indexed admin);

    /// @notice Error thrown when attempting to use an unapproved currency.
    /// @param currency The currency that is not approved.
    error CurrencyNotAllowed(address currency);

    /// @dev Ensures that the provided currency has been approved for ledger operations.
    modifier onlyAllowedCurrency(address currency) {
        if (!_isCurrencyAllowed(currency)) revert CurrencyNotAllowed(currency);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __Pausable_init();
        __LockOperator_init();
        __UUPSUpgradeable_init();
        __BalanceOperator_init();
        __AllowanceOperator_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Locks a specific amount of funds for a given account.
    /// @dev The funds are immobilized and cannot be withdrawn or transferred until released.
    ///      Only operator role can handle this methods.
    ///      An approval is not needed, the protocol operate directly on the user funds to simplify operations.
    /// @param account The address of the account for which the funds will be locked.
    /// @param amount The amount of funds to lock.
    /// @param currency The currency to associate lock with. Use address(0) for the native coin.
    function lock(
        address account,
        uint256 amount,
        address currency
    ) external
        restricted
        whenNotPaused
        onlyValidOperation(account, amount)
        onlyAllowedCurrency(currency)
        returns (uint256)
    {
        return _lock(account, amount, currency);
    }

    /// @notice Release a specific amount of funds from locked pool.
    /// @param account The address of the account for which the funds will be released.
    /// @param amount The amount of funds to release.
    /// @param currency The currency to associate release with. Use address(0) for the native coin.
    function release(
        address account,
        uint256 amount,
        address currency
    ) external
        restricted
        whenNotPaused
        onlyValidOperation(account, amount)
        onlyAllowedCurrency(currency)
        returns (uint256)
    {
        return _release(account, amount, currency);
    }

    /// @notice Claims a specific amount of locked funds on behalf of a claimer.
    /// @dev The claimer is authorized to process the funds from the account.
    ///      Only operator role can handle this methods.
    /// @param account The address of the account whose funds are being claimed.
    /// @param amount The amount of funds to claim.
    /// @param currency The currency to associate claim with. Use address(0) for the native coin.
    function claim(
        address account,
        uint256 amount,
        address currency
    ) external
        restricted
        whenNotPaused
        onlyValidOperation(account, amount)
        onlyAllowedCurrency(currency)
        returns (uint256)
    {
        return _claim(account, amount, currency);
    }

    /// @notice Approves a specific amount of funds from the caller's balance for a recipient.
    /// @param to The address of the recipient for whom the funds are being approved.
    /// @param amount The amount of funds to approve.
    /// @param currency The address of the ERC20 token to approve. Use `address(0)` for native tokens.
    function approve(
        address to,
        uint256 amount,
        address currency
    ) external whenNotPaused onlyAllowedCurrency(currency) returns (uint256) {
        return _approve(to, amount, currency);
    }

    /// @notice Revokes the approved funds from the caller's balance for a specific recipient.
    /// @param to The address of the recipient whose approval is being revoked.
    /// @param currency The address of the ERC20 token associated with the approval. Use `address(0)` for native tokens.
    /// @return The amount of funds that were revoked from the approval.
    function revoke(
        address to,
        uint256 amount,
        address currency
    ) external whenNotPaused onlyAllowedCurrency(currency) returns (uint256) {
        return _revoke(to, amount, currency);
    }

    /// @notice Collects a specific amount of previously approved funds.
    /// @param from The address of the account from which the approved funds are being collected.
    /// @param amount The amount of funds to collect.
    /// @param currency The address of the ERC20 token to collect. Use `address(0)` for native tokens.
    function collect(
        address from,
        uint256 amount,
        address currency
    ) external whenNotPaused onlyAllowedCurrency(currency) returns (uint256) {
        return _collect(from, amount, currency);
    }

    /// @notice Deposits a specified amount of currency into the contract for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(
        address recipient,
        uint256 amount,
        address currency
    ) external payable whenNotPaused onlyAllowedCurrency(currency) returns (uint256) {
        return _deposit(recipient, amount, currency);
    }

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(
        address recipient,
        uint256 amount,
        address currency
    ) external whenNotPaused onlyAllowedCurrency(currency) nonReentrant returns (uint256) {
        return _withdraw(recipient, amount, currency);
    }

    /// @notice Transfers tokens internally within the ledger from the caller to a specified recipient.
    /// @param recipient The address of the account to credit with the transfer.
    /// @param amount The amount of tokens to transfer.
    /// @param currency The address of the currency to transfer. Use `address(0)` for the native coin.
    function transfer(
        address recipient,
        uint256 amount,
        address currency
    ) external whenNotPaused onlyAllowedCurrency(currency) returns (uint256) {
        return _transfer(recipient, amount, currency);
    }

    /// @notice Allows a currency to be used within the ledger operations.
    /// @param currency The address of the currency to allow. Use address(0) for the native coin.
    function allowCurrency(address currency) external restricted {
        _setCurrencyState(currency, true);
    }

    /// @notice Blocks a currency from being used within the ledger operations.
    /// @param currency The address of the currency to block. Use address(0) for the native coin.
    function blockCurrency(address currency) external restricted {
        _setCurrencyState(currency, false);
    }

    /// @notice Returns whether a currency is approved for ledger operations.
    /// @param currency The address of the currency to verify.
    function isCurrencyAllowed(address currency) external view returns (bool) {
        return _isCurrencyAllowed(currency);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @dev Registers the approval status for a currency and emits an event if the value changes.
    function _setCurrencyState(address currency, bool allowed) private {
        if (_approvedCurrencies[currency] == allowed) return;
        _approvedCurrencies[currency] = allowed;
        emit CurrencyApprovalUpdated(currency, allowed, msg.sender);
    }

    /// @dev Returns true when the currency is currently approved, false otherwise.
    function _isCurrencyAllowed(address currency) private view returns (bool) {
        return _approvedCurrencies[currency];
    }
}
