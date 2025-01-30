// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IERC721StatefulVerifiable
/// @notice Interface for verifying the active status of an ERC721 token.
/// @dev This interface allows checking whether a token is in an active state,
///      ensuring compliance with stateful ERC721 implementations.
interface IERC721StatefulVerifiable {
    /// @notice Checks whether a specific token is in an active state.
    /// @dev Used to verify if the token is currently active within the system.
    /// @param tokenId The unique identifier of the ERC721 token.
    /// @return A boolean indicating whether the token is active (`true`) or inactive (`false`).
    function isActive(uint256 tokenId) external view returns (bool);
}
