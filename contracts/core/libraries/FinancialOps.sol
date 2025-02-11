// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FinancialOps
/// @notice Library to assist with financial multicurrency operations.
// TODO: If needed this library could be deployed separately and linked.
library FinancialOps {
    using SafeERC20 for IERC20;

    /// @notice Error to be thrown when a transfer fails.
    /// @param reason The reason for the transfer failure.
    error FailDuringTransfer(string reason);
    /// @notice Error to be thrown when a deposit fails.
    /// @param reason The reason for the deposit failure.
    error FailDuringDeposit(string reason);

    /// @notice Handles the transfer of native cryptocurrency.
    /// @param to The address to which the native cryptocurrency will be transferred.
    /// @param amount The amount of native cryptocurrency to transfer.
    function _nativeTransfer(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{ value: amount }("");
        if (!success) revert FailDuringTransfer("Transfer failed");
    }

    /// @notice Handles the transfer of ERC20 tokens.
    /// @param to The address to which the ERC20 tokens will be transferred.
    /// @param amount The amount of ERC20 tokens to transfer.
    /// @param token The address of the ERC20 token to transfer.
    function _erc20Transfer(address to, uint256 amount, address token) internal {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice Deposits the native currency of the network (e.g., ETH on Ethereum).
    /// @dev No explicit transfer is needed as the transfer occurs implicitly via msg.value.
    /// @param amount The amount to deposit.
    /// @return The deposited amount.
    function _nativeDeposit(uint256 amount) internal returns (uint256) {
        if (amount > msg.value) revert FailDuringDeposit("Amount exceeds balance sent.");
        // the transfer is not needed since the transfer is implicit here
        return amount;
    }

    /// @notice Deposits ERC20 tokens from a specified address.
    /// @dev Requires the `from` address to have previously approved the transfer amount.
    /// @param from The address of the sender authorizing the transfer.
    /// @param amount The amount of tokens to transfer.
    /// @param token The address of the ERC20 token contract.
    /// @return The deposited amount.
    function _erc20Deposit(address from, uint256 amount, address token) internal returns (uint256) {
        if (amount > allowance(from, token)) revert FailDuringDeposit("Amount exceeds allowance.");
        // disable slitter use 'arbitrary transfer form' since the use of `safeDeposit` is handled in a safe manner.
        // eg. msg.sender.safeDeposit(total, currency); <- Use msg.sender as from in transferFrom.
        // slither-disable-next-line arbitrary-send-erc20
        IERC20(token).safeTransferFrom(from, address(this), amount);
        return amount;
    }

    /// @notice Increases the allowance of a given `spender` for a specified ERC20 `token`.
    /// @dev This function safely increases the allowance using OpenZeppelin's SafeERC20 library.
    /// @param spender The address that will be granted an additional spending allowance.
    /// @param amount The additional amount to add to the spender's allowance.
    /// @param token The address of the ERC20 token contract for which the allowance is increased.
    ///              Use `address(0)` for native tokens, where this function will have no effect.
    function increaseAllowance(address spender, uint256 amount, address token) internal {
        if (token == address(0) || amount == 0) revert FailDuringDeposit("Invalid spender or allowance attempt");
        IERC20(token).safeIncreaseAllowance(spender, amount);
    }

    /// @notice Checks the allowance that the contract has been granted by the owner for a specific ERC20 token.
    /// @dev For native tokens (if `token` is address(0)), the concept of allowance does not apply,
    ///      so this function simply returns `msg.value`, representing the amount sent in the transaction.
    /// @param owner The address of the token owner who has granted the allowance.
    /// @param token The address of the ERC20 token contract or `address(0)` for native tokens.
    /// @return The allowance amount for ERC20 tokens, or `msg.value` if it’s a native token.
    function allowance(address owner, address token) internal view returns (uint256) {
        if (token == address(0)) return msg.value;
        return IERC20(token).allowance(owner, address(this));
    }

    /// @notice Deposit Native coin or ERC20 tokens to the contract using SafeERC20's safeTransferFrom method.
    /// @dev This function ensures that the transfer is executed safely, handling any potential reverts.
    /// Expect exactly the declared amount as allowance for token or value for native.
    /// @param from The address from which the tokens will be transferred.
    /// @param amount The amount of tokens to deposit.
    /// @param token The address of the token to deposit.
    function safeDeposit(address from, uint256 amount, address token) internal returns (uint256) {
        if (amount == 0) revert FailDuringDeposit("Invalid zero amount.");
        if (token == address(0)) return _nativeDeposit(amount);
        return _erc20Deposit(from, amount, token);
    }

    /// @notice Retrieves the balance of Native or ERC20 tokens for the specified address.
    /// @param target The address whose balance will be retrieved.
    /// @param token The address of the token to check. Use address(0) for native tokens.
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
        _erc20Transfer(to, amount, token);
    }
}
