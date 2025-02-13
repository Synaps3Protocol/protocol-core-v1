// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

/// @title IAssetSafe
/// @notice Interface for a secure asset storage system that manages encrypted metadata.
/// @dev This interface defines methods for retrieving and storing encrypted complementary data
///      associated with specific asset IDs.
interface IAssetSafe {
    /// @notice Retrieves the encrypted content for a given asset ID and vault type.
    /// @dev The function should ensure only authorized users can access the content.
    /// @param assetId The unique identifier of the asset whose content is being requested.
    /// @param vault The encryption method used to secure the asset (e.g., LIT, RSA, EC).
    /// @return A `bytes` array representing the encrypted content.
    function getContent(uint256 assetId, T.Cipher vault) external view returns (bytes memory);

    /// @notice Retrieves the "safe" scheme type associated with a given asset ID.
    /// @param assetId The identifier of the asset.
    /// @return The encryption scheme used for the asset.
    function getType(uint256 assetId) external view returns (T.Cipher);

    /// @notice Stores encrypted content in the safe under a specific asset ID.
    /// @dev The stored data should be securely associated with the asset ID and encryption scheme.
    /// @param assetId The unique identifier of the asset to store.
    /// @param vault The encryption method used (e.g., LIT, RSA, EC).
    /// @param data The encrypted content represented as a `bytes` array.
    function setContent(uint256 assetId, T.Cipher vault, bytes memory data) external;
}
