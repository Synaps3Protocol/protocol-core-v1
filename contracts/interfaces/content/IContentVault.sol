// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "contracts/libraries/Types.sol";

/// @title IContentVault
/// @notice Interface for a content vault that manages secured content.
/// @dev This interface defines the methods to retrieve and store content.
interface IContentVault {
    /// @notice Retrieves the encrypted content for a given content ID.
    /// @param contentId The identifier of the content.
    /// @param vault The vault type used to retrieve the content (e.g., LIT, RSA, EC).
    function getContent(uint256 contentId, T.VaultType vault) external view returns (bytes memory);

    /// @notice Stores encrypted content in the vault under a specific content ID.
    /// @param contentId The identifier of the content.
    /// @param vault The vault type to associate with the encrypted content (e.g., LIT, RSA, EC).
    /// @param data The secure content to store, represented as bytes.
    function setContent(uint256 contentId, T.VaultType vault, bytes memory data) external;
}
