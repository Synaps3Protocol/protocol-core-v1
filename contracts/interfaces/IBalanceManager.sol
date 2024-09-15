// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBalanceManager Interface
/// @notice This interface defines a method to retrieve the balance of a contract for a specified currency.
interface IBalanceManager {
    /// @notice Returns the contract's balance for the specified currency.
    /// @dev The function checks the balance for both native and ERC-20 tokens.
    /// @param currency The address of the token to check the balance of. Use address(0) for native currency (e.g., ETH).
    /// @return The balance of the contract in the specified currency (in wei or token decimals).
    function getBalance(address currency) external view returns (uint256);
}