// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { BalanceOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

/// @title LedgerVault
/// @notice A vault contract designed to store, lock, release, and manage funds securely.
/// @dev This contract includes administrative methods (`restricted`) and general user methods.
///      Supports operations such as deposits, withdrawals, transfers, and locked funds management.
contract LedgerVault is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    BalanceOperatorUpgradeable
{
    using FinancialOps for address;

    /// @dev Holds the registry of locked funds for accounts.
    mapping(address => mapping(address => uint256)) private _locked;

    /// @notice Emitted when funds are locked in the ledger.
    /// @param account The address of the account whose funds were locked.
    /// @param amount The amount of funds that were locked.
    /// @param currency The address of the currency in which the funds were locked.
    event FundsLocked(address indexed account, uint256 amount, address indexed currency);

    /// @notice Emitted when locked funds are successfully released.
    /// @param account The address of the account whose funds were released.
    /// @param amount The amount of funds that were locked.
    /// @param currency The address of the currency in which the funds were locked.
    event FundsReleased(address indexed account, uint256 amount, address indexed currency);

    /// @notice Emitted when locked funds are successfully claimed.
    /// @param claimer The address of the entity claiming the funds.
    /// @param amount The amount of funds claimed.
    /// @param currency The address of the currency in which the funds were claimed.
    event FundsClaimed(address indexed claimer, uint256 amount, address indexed currency);

    /// @notice Thrown when there are no available funds to lock.
    /// @dev This error occurs if an account attempts to lock more funds than available.
    error NoFundsToLock();

    /// @notice Thrown when there are no locked funds available to claim.
    /// @dev This error occurs if an account or claimer tries to claim funds that are not locked or insufficient.
    error NoFundsToClaim();

    /// @notice Thrown when there are no locked funds available to release.
    /// @dev This error occurs if an operator tries to releases funds that are not locked or insufficient.
    error NoFundsToRelease();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __BalanceOperator_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Deposits a specified amount of currency into the pool for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address recipient, uint256 amount, address currency) external returns (uint256) {
        uint256 confirmed = _deposit(recipient, amount, currency);
        emit FundsDeposited(recipient, msg.sender, confirmed, currency);
        return confirmed;
    }

    // TODO withdraw speed bump time lock
    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @dev This function withdraws funds from the caller's balance and transfers them to the recipient.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external nonReentrant returns (uint256) {
        uint256 confirmed = _withdraw(recipient, amount, currency);
        emit FundsWithdrawn(recipient, msg.sender, confirmed, currency);
        return confirmed;
    }

    /// @notice Transfers a specified amount of currency from the caller's balance to a given recipient.
    /// @dev Ensures the caller has sufficient balance before performing the transfer. Updates the ledger accordingly.
    /// @param recipient The address of the account to credit with the transfer.
    /// @param amount The amount of currency to transfer.
    /// @param currency The address of the ERC20 token to transfer. Use `address(0)` for native tokens.
    function transfer(address recipient, uint256 amount, address currency) external returns (uint256) {
        uint256 confirmed = _transfer(recipient, amount, currency);
        emit FundsTransferred(recipient, msg.sender, confirmed, currency);
        return confirmed;
    }

    /// @notice Locks a specific amount of funds for a given account.
    /// @dev The funds are immobilized and cannot be withdrawn or transferred until released or claimed.
    ///      Only operator role can handle this methods.
    /// @param account The address of the account for which the funds will be locked.
    /// @param amount The amount of funds to lock.
    /// @param currency The currency to associate lock with. Use address(0) for the native coin.
    function lock(address account, uint256 amount, address currency) external restricted returns (uint256) {
        if (getLedgerBalance(account, currency) < amount) revert NoFundsToLock();
        _subLedgerEntry(account, amount, currency);
        _sumLockedAmount(account, amount, currency);
        emit FundsLocked(account, amount, currency);
        return amount;
    }

    /// @notice Release a specific amount of funds from locked pool.
    /// @param account The address of the account for which the funds will be released.
    /// @param amount The amount of funds to release.
    /// @param currency The currency to associate release with. Use address(0) for the native coin.
    function release(address account, uint256 amount, address currency) external restricted returns (uint256) {
        if (_getLockedAmount(account, currency) < amount) revert NoFundsToRelease();
        _subLockedAmount(account, amount, currency);
        _sumLedgerEntry(account, amount, currency);
        emit FundsReleased(account, amount, currency);
        return amount;
    }

    /// @notice Claims a specific amount of locked funds on behalf of a claimer.
    /// @dev The claimer is authorized to process the funds from the account.
    ///      Only operator role can handle this methods.
    /// @param account The address of the account whose funds are being claimed.
    /// @param amount The amount of funds to claim.
    /// @param currency The currency to associate claim with. Use address(0) for the native coin.
    function claim(address account, uint256 amount, address currency) external restricted returns (uint256) {
        if (_getLockedAmount(account, currency) < amount) revert NoFundsToClaim();
        _subLockedAmount(account, amount, currency); //
        _sumLedgerEntry(msg.sender, amount, currency);
        emit FundsClaimed(msg.sender, amount, currency);
        return amount;
    }

    /// @notice Reduces the locked funds of an account for a specific currency.
    /// @dev Deducts the specified `amount` from the `_locked` mapping for the given `account` and `currency`.
    /// @param account The address of the account whose locked funds are being reduced.
    /// @param amount The amount to subtract from the locked balance.
    /// @param currency The address of the currency being reduced.
    function _subLockedAmount(address account, uint256 amount, address currency) private {
        _locked[account][currency] -= amount;
    }

    /// @notice Increases the locked funds of an account for a specific currency.
    /// @dev Adds the specified `amount` to the `_locked` mapping for the given `account` and `currency`.
    /// @param account The address of the account whose locked funds are being increased.
    /// @param amount The amount to add to the locked balance.
    /// @param currency The address of the currency being increased.
    function _sumLockedAmount(address account, uint256 amount, address currency) private {
        _locked[account][currency] += amount;
    }

    /// @notice Retrieves the locked balance of an account for a specific currency.
    /// @dev Returns the value stored in the `_locked` mapping for the given `account` and `currency`.
    /// @param account The address of the account whose locked balance is being queried.
    /// @param currency The address of the currency to check the locked balance for.
    /// @return The locked balance of the specified account for the given currency.
    function _getLockedAmount(address account, address currency) private view returns (uint256) {
        return _locked[account][currency];
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
