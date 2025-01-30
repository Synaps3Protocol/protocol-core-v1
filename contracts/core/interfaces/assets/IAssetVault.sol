// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

/// @title IAssetVault
/// @notice Interface for a secure content vault that manages encrypted digital assets.
/// @dev This interface provides methods for retrieving and storing
///      encrypted content associated with specific asset IDs.
interface IAssetVault {
    /// @notice Retrieves the encrypted content for a given asset ID and vault type.
    /// @dev The function should ensure only authorized users can access the content.
    /// @param assetId The unique identifier of the asset whose content is being requested.
    /// @param vault The vault type that was used to encrypt the asset (e.g., LIT, RSA, EC).
    /// @return A `bytes` array representing the encrypted content.
    function getContent(uint256 assetId, T.VaultType vault) external view returns (bytes memory);

    /// @notice Stores encrypted content in the vault under a specific asset ID.
    /// @dev The stored data should be securely associated with the asset ID and vault type.
    /// @param assetId The unique identifier of the asset to store.
    /// @param vault The encryption method or vault type used (e.g., LIT, RSA, EC).
    /// @param data The encrypted content represented as a `bytes` array.
    function setContent(uint256 assetId, T.VaultType vault, bytes memory data) external;
}
