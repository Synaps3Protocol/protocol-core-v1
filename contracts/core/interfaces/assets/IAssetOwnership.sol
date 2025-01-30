// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/// @title IAssetOwnership
/// @notice Interface for managing asset ownership as ERC721 tokens.
/// @dev Extends ERC721 and ERC721Metadata to provide full NFT functionality,
///      including ownership tracking and metadata retrieval.
interface IAssetOwnership is IERC721, IERC721Metadata {
    /// @notice Registers a new asset as an NFT.
    /// @dev The asset must have a unique identifier (`assetId`) that serves as the token ID.
    /// @param to The address that will own the minted NFT.
    /// @param assetId The unique identifier for the asset, serving as the NFT ID.
    function register(address to, uint256 assetId) external;
}
