// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "contracts/core/primitives/Types.sol";

/// @title IAssetVault
/// @notice Interface for a content vault that manages secured content.
/// @dev This interface defines the methods to retrieve and store content.
interface IAssetVault {
    /// @notice Retrieves the encrypted content for a given content ID.
    /// @param assetId The identifier of the asset.
    /// @param vault The vault type used to retrieve the asset (e.g., LIT, RSA, EC).
    function getContent(uint256 assetId, T.VaultType vault) external view returns (bytes memory);

    /// @notice Stores encrypted content in the vault under a specific content ID.
    /// @param assetId The identifier of the asset.
    /// @param vault The vault type to associate with the encrypted content (e.g., LIT, RSA, EC).
    /// @param data The secure content to store, represented as bytes.
    function setContent(uint256 assetId, T.VaultType vault, bytes memory data) external;
}
