// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IAssetOwnership is IERC721, IERC721Metadata {
    /// @notice Mints a new NFT representing an asset to the specified address.
    /// @dev The assumption is that only those who know the asset ID and have the required approval can mint the corresponding token.
    /// @param to The address to mint the NFT to.
    /// @param assetId The unique identifier for the asset, which serves as the NFT ID.
    function registerAsset(address to, uint256 assetId) external;
}
