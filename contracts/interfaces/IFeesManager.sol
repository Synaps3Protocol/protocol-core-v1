// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFeesManager {
    /// @notice Sets a new treasury fee.
    /// @param newTreasuryFee The new treasury fee.
    /// @notice Only the owner can call this function.
    function setFees(uint256 newTreasuryFee) external;

    /// @notice Sets a new treasury fee.
    /// @param newTreasuryFee The new treasury fee %.
    /// @param token The token to set the fees.
    /// @notice Only the owner can call this function.
    function setFees(uint256 newTreasuryFee, address token) external;

    /// @notice Returns the current treasury fee %. 
    /// @param token The address of the token.
    /// @return The treasury fee.
    function getFees(address token) external view returns (uint256);
}