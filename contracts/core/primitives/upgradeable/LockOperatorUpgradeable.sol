// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { LedgerUpgradeable } from "@synaps3/core/primitives/upgradeable/LedgerUpgradeable.sol";
import { ILockOperator } from "@synaps3/core/interfaces/base/ILockOperator.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

abstract contract LockOperatorUpgradeable is Initializable, LedgerUpgradeable, ILockOperator {
    using FinancialOps for address;

    /// @custom:storage-location erc7201:lockoperatorupgradeable
    struct LockOperatorStorage {
        /// @dev Holds the relation between approved funds, the currency, and amount
        /// @dev Holds the registry of locked funds for accounts.
        mapping(address => mapping(address => uint256)) _locked;
    }

    /// @dev Storage slot for LockOperatorUpgradeable, calculated using a unique namespace to avoid conflicts.
    /// The `LOCK_OPERATOR_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant LOCK_OPERATOR_SLOT = 0xece3ff917f3a3127e521e0c3f2f90ff09a3c8199be32f9b40bff79e776960800;

    /// @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    /// This is the method to initialize this contract and any other extended contracts.
    /// slither-disable-next-line naming-convention
    function __LockOperator_init() internal onlyInitializing {
        __Ledger_init();
    }

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    /// This is the method to initialize this contract as standalone.
    /// slither-disable-next-line naming-convention
    function __LockOperator_init_unchained() internal onlyInitializing {}

    /// @notice Locks a specific amount of funds for a given account.
    /// @dev The funds are immobilized and cannot be withdrawn or transferred until released.
    ///      Only operator role can handle this methods.
    ///      An approval is not needed, the protocol operate directly on the user funds to simplify operations.
    /// @param account The address of the account for which the funds will be locked.
    /// @param amount The amount of funds to lock.
    /// @param currency The currency to associate lock with. Use address(0) for the native coin.
    function _lock(
        address account,
        uint256 amount,
        address currency
    ) internal onlyValidOperation(account, amount) returns (uint256) {
        if (getLedgerBalance(account, currency) < amount) revert NoFundsToLock();
        _subLedgerEntry(account, amount, currency);
        _sumLockedAmount(account, amount, currency);
        emit FundsLocked(msg.sender, account, amount, currency);
        return amount;
    }

    /// @notice Release a specific amount of funds from locked pool.
    /// @param account The address of the account for which the funds will be released.
    /// @param amount The amount of funds to release.
    /// @param currency The currency to associate release with. Use address(0) for the native coin.
    function _release(
        address account,
        uint256 amount,
        address currency
    ) internal onlyValidOperation(account, amount) returns (uint256) {
        if (_getLockedAmount(account, currency) < amount) revert NoFundsToRelease();
        _subLockedAmount(account, amount, currency);
        _sumLedgerEntry(account, amount, currency);
        emit FundsReleased(msg.sender, account, amount, currency);
        return amount;
    }

    /// @notice Claims a specific amount of locked funds on behalf of a claimer.
    /// @dev The claimer is authorized to process the funds from the account.
    ///      Only operator role can handle this methods.
    /// @param account The address of the account whose funds are being claimed.
    /// @param amount The amount of funds to claim.
    /// @param currency The currency to associate claim with. Use address(0) for the native coin.
    function _claim(
        address account,
        uint256 amount,
        address currency
    ) internal onlyValidOperation(account, amount) returns (uint256) {
        if (_getLockedAmount(account, currency) < amount) revert NoFundsToClaim();
        _subLockedAmount(account, amount, currency); //
        _sumLedgerEntry(msg.sender, amount, currency);
        emit FundsClaimed(msg.sender, account, amount, currency);
        return amount;
    }

    /// @notice Reduces the locked funds of an account for a specific currency.
    /// @dev Deducts the specified `amount` from the `_locked` mapping for the given `account` and `currency`.
    /// @param account The address of the account whose locked funds are being reduced.
    /// @param amount The amount to subtract from the locked balance.
    /// @param currency The address of the currency being reduced.
    function _subLockedAmount(address account, uint256 amount, address currency) private {
        LockOperatorStorage storage $ = _getLockOperatorStorage();
        $._locked[account][currency] -= amount;
    }

    /// @notice Increases the locked funds of an account for a specific currency.
    /// @dev Adds the specified `amount` to the `_locked` mapping for the given `account` and `currency`.
    /// @param account The address of the account whose locked funds are being increased.
    /// @param amount The amount to add to the locked balance.
    /// @param currency The address of the currency being increased.
    function _sumLockedAmount(address account, uint256 amount, address currency) private {
        LockOperatorStorage storage $ = _getLockOperatorStorage();
        $._locked[account][currency] += amount;
    }

    /// @notice Retrieves the locked balance of an account for a specific currency.
    /// @dev Returns the value stored in the `_locked` mapping for the given `account` and `currency`.
    /// @param account The address of the account whose locked balance is being queried.
    /// @param currency The address of the currency to check the locked balance for.
    /// @return The locked balance of the specified account for the given currency.
    function _getLockedAmount(address account, address currency) private view returns (uint256) {
        LockOperatorStorage storage $ = _getLockOperatorStorage();
        return $._locked[account][currency];
    }

    /// @notice Internal function to get the allowance operator storage.
    /// @dev Uses assembly to retrieve the storage at the pre-calculated storage slot.
    function _getLockOperatorStorage() private pure returns (LockOperatorStorage storage $) {
        assembly {
            $.slot := LOCK_OPERATOR_SLOT
        }
    }
}
