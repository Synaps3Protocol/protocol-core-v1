// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TreasuryHelper
/// @notice Library to assist with treasury operations.
library TreasuryHelper {
    using SafeERC20 for IERC20;

    /// @notice Error to be thrown when a transfer fails.
    /// @param reason The reason for the transfer failure.
    error FailDuringTransfer(string reason);

    /// @notice Handles the transfer of native cryptocurrency.
    /// @param to The address to which the native cryptocurrency will be transferred.
    /// @param amount The amount of native cryptocurrency to transfer.
    function _nativeTransfer(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{ value: amount }("");
        if (!success) revert FailDuringTransfer("Transfer failed");
    }

    /// @notice Handles the transfer of ERC20 tokens.
    /// @param token The address of the ERC20 token to transfer.
    /// @param to The address to which the ERC20 tokens will be transferred.
    /// @param amount The amount of ERC20 tokens to transfer.
    function _erc20Transfer(address token, address to, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice Checks the allowance that the contract has been granted by the owner for a specific ERC20 token.
    /// @dev This internal function queries the allowance that the `owner` has granted
    /// to this contract for spending the specified `token`.
    /// @param owner The address of the token owner who has granted the allowance.
    /// @param token The address of the ERC20 token contract.
    /// @return The remaining number of tokens that the contract is allowed to spend on behalf of the `owner`.
    function allowance(address owner, address token) internal view returns (uint256) {
        return IERC20(token).allowance(owner, address(this));
    }

    /// @notice Deposit Native coin or ERC20 tokens to the contract using SafeERC20's safeTransferFrom method.
    /// @dev This function ensures that the transfer is executed safely, handling any potential reverts.
    /// Expect exactly the declared amount as allowance for token or value for native.
    /// @param from The address from which the tokens will be transferred.
    /// @param amount The amount of tokens to deposit.
    /// @param token The address of the token to deposit.
    function safeDeposit(address from, uint256 amount, address token) internal returns (uint256) {
        if (amount == 0) return amount;
        if (token == address(0)) {
            if (amount > msg.value) revert FailDuringTransfer("Invalid transaction amount sent");
            // the transfer is not needed since the transfer is implicit here
            return amount;
        }

        if (amount > allowance(from, token)) revert FailDuringTransfer("Invalid allowance.");
        // disable slitter use 'arbitraty transfer form' since the use of `safeDeposit` is handled in a safe manner.
        // eg. msg.sender.safeDeposit(total, currency); <- Use msg.sender as from in transferFrom.
        // slither-disable-next-line arbitrary-send-erc20
        IERC20(token).safeTransferFrom(from, address(this), amount);
        return amount;
    }

    /// @notice Retrieves the balance of Native or ERC20 tokens for the specified address.
    /// @param target The address whose balance will be retrieved.
    /// @param token The address of the token to check. Use address(0) for native tokens.
    /// @return The balance of the specified tokens at the target address.
    function balanceOf(address target, address token) internal view returns (uint256) {
        if (token == address(0)) return target.balance;
        return IERC20(token).balanceOf(target);
    }

    /// @notice Transfer funds from the contract to the specified address.
    /// @dev Handles the transfer of native tokens and ERC20 tokens.
    /// @param to The address to which the tokens will be sent.
    /// @param amount The amount of tokens to transfer.
    /// @param token The address of the ERC20 token to transfer or address(0) for native token.
    function transfer(address to, uint256 amount, address token) internal {
        if (amount == 0) revert FailDuringTransfer("Invalid zero amount to transfer.");
        if (balanceOf(address(this), token) < amount) revert FailDuringTransfer("Insufficient balance.");
        if (token == address(0)) return _nativeTransfer(to, amount);
        _erc20Transfer(token, to, amount);
    }
}
