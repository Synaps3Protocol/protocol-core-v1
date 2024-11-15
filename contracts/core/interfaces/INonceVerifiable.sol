// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title INonceVerifiable Interface
/// @dev This interface provides functionality to track and verify nonces for addresses.
interface INonceVerifiable {
    /// @notice Returns the next unused nonce for the specified address.
    /// @param owner The address of the owner whose nonce is being queried.
    /// @return The next unused nonce for the specified address.
    function nonces(address owner) external view returns (uint256);
}
