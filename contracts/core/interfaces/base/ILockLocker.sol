/// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ILockLocker
/// @notice Interface for locking funds in an account.
interface ILockLocker {
    /// @notice Emitted when funds are locked.
    /// @param initiator Address that initiates the operation.
    /// @param from Account whose funds are being locked.
    /// @param amount Amount locked.
    /// @param currency Currency address; use address(0) for native coin.
    event FundsLocked(address indexed initiator, address indexed from, uint256 amount, address indexed currency);

    /// @notice Error raised when there are not enough funds to lock.
    error NoFundsToLock();

    /// @notice Locks a specific amount of funds for a given account.
    /// @param account The address of the account whose funds will be locked.
    /// @param amount  The amount of funds to lock.
    /// @param currency The currency to associate with the lock; use address(0) for the native coin.
    /// @return An identifier or updated state depending on implementation.
    function lock(address account, uint256 amount, address currency) external returns (uint256);
}
