// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IDisburser Interface
/// @notice This interface defines the functionality for disbursing funds from the contract to specified addresses.
/// @dev Implementers of this interface should ensure that the disbursement of funds is managed securely, and that
///      only authorized roles can call these functions to avoid unintended distribution of funds.
interface IDisburser {
    /// @notice Disburses tokens from the contract to a specified address.
    /// @param amount The amount of tokens to disburse.
    /// @param token The address of the ERC20 token to disburse tokens.
    /// @dev This function can only be called by governance or an authorized entity.
    function disburse(uint256 amount, address token) external;

    /// @notice Disburses tokens from the contract to a specified address.
    /// @param amount The amount of tokens to disburse.
    /// @dev This function can only be called by governance or an authorized entity.
    function disburse(uint256 amount) external;
}
