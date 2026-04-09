/// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ILockClaimer
/// @notice Interface for claiming locked funds in favor of an authorized claimer.
interface ILockClaimer {
    /// @notice Emitted when locked funds are claimed.
    /// @param initiator Address that initiates the operation (claimer).
    /// @param from Account from which funds are claimed.
    /// @param amount Amount claimed.
    /// @param currency Currency address; use address(0) for native coin.
    event FundsClaimed(address indexed initiator, address indexed from, uint256 amount, address indexed currency);

    /// @notice Error raised when there are not enough locked funds to claim.
    error NoFundsToClaim();

    /// @notice Claims a specific amount of locked funds on behalf of an authorized claimer.
    /// @param account The address of the account whose funds are being claimed.
    /// @param amount  The amount of funds to claim.
    /// @param currency The currency to associate with the claim; use address(0) for the native coin.
    /// @return An identifier or updated state depending on implementation.
    function claim(address account, uint256 amount, address currency) external returns (uint256);
}
