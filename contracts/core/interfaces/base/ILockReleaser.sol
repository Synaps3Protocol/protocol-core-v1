/// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ILockReleaser
/// @notice Interface for releasing previously locked funds.
interface ILockReleaser {
    /// @notice Emitted when locked funds are released.
    /// @param initiator Address that initiates the operation.
    /// @param recipient Account receiving the released funds.
    /// @param amount Amount released.
    /// @param currency Currency address; use address(0) for native coin.
    event FundsReleased(address indexed initiator, address indexed recipient, uint256 amount, address indexed currency);

    /// @notice Error raised when there are not enough locked funds to release.
    error NoFundsToRelease();

    /// @notice Releases a specific amount of funds from the locked pool.
    /// @param account The address of the account whose funds will be released.
    /// @param amount  The amount of funds to release.
    /// @param currency The currency to associate with the release; use address(0) for the native coin.
    /// @return An identifier or updated state depending on implementation.
    function release(address account, uint256 amount, address currency) external returns (uint256);
}
