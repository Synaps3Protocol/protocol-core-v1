// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITreasury {
    /// @notice Withdraws tokens from the contract to the owner's address.
    /// @param amount The amount of tokens to withdraw.
    /// @notice This function can only be called by the owner of the contract.
    function withdraw(uint256 amount) external;

    /// @notice Withdraws tokens from the contract to the owner's address.
    /// @param amount The amount of tokens to withdraw.
    /// @param token The address of the ERC20 token to withdraw or address(0) to withdraw native tokens.
    /// @notice This function can only be called by the owner of the contract.
    function withdraw(uint256 amount, address token) external;

    /// @notice Sets a new treasury fee.
    /// @param newTreasuryFee The new treasury fee.
    /// @notice Only the owner can call this function.
    function setTreasuryFee(uint256 newTreasuryFee) external;

    /// @notice Sets a new treasury fee.
    /// @param newTreasuryFee The new treasury fee.
    /// @param token The token to set the fees.
    /// @notice Only the owner can call this function.
    function setTreasuryFee(uint256 newTreasuryFee, address token) external;

    /// @notice Returns the current treasury fee.
    /// @param token The address of the token.
    /// @return The treasury fee.
    function getTreasuryFee(address token) external view returns (uint256);
}