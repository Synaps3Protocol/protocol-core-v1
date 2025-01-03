// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
// solhint-disable-next-line max-line-length
import { ERC721EnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { IAssetVerifiable } from "@synaps3/core/interfaces/assets/IAssetVerifiable.sol";
import { IAssetOwnership } from "@synaps3/core/interfaces/assets/IAssetOwnership.sol";

// TODO check ERC-404: fractional
// TODO check ERC-2981: royalties
// TODO check ERC-4804: url scheme
// TODO check ERC-6551: attach asset level terms, restrictions, etc

/// @title Ownership ERC721 Upgradeable
/// @notice This abstract contract manages the ownership.
contract AssetOwnership is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    AccessControlledUpgradeable,
    ERC721EnumerableUpgradeable,
    IAssetOwnership
{
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAssetVerifiable public immutable ASSET_REFERENDUM;

    /// @dev Emitted when a new content item is registered on the platform.
    /// @param owner The address of the asset creator or owner who registered the asset.
    /// @param assetId The unique identifier for the registered content.
    event RegisteredAsset(address indexed owner, uint256 assetId);

    /// @dev Error indicating that an operation attempted to reference content that has not been approved.
    /// This error is triggered when the asset being accessed or referenced is not in an approved state.
    error InvalidNotApprovedAsset();

    /// @notice Modifier to ensure content is approved before distribution.
    /// @param to The address attempting to distribute the asset.
    /// @param assetId The ID of the asset to be distributed.
    /// @dev the asset must be approved by referendum or the recipient must have a verified role.
    /// This modifier checks if the asset is approved by referendum or if the recipient has a verified role.
    /// It also ensures that the recipient is the one who initially submitted the asset for approval.
    modifier onlyApprovedAsset(address to, uint256 assetId) {
        // Revert if the asset is not approved or if the recipient is not the original submitter
        if (!ASSET_REFERENDUM.isApproved(to, assetId)) {
            revert InvalidNotApprovedAsset();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address assetReferendum) {
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        _disableInitializers();
        // we need to verify the status of each content before allow register it.
        ASSET_REFERENDUM = IAssetVerifiable(assetReferendum);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __ERC721Enumerable_init();
        __ERC721_init("SynapseIP", "SYN");
        __AccessControlled_init(accessManager);
    }

    /// @notice Checks if the contract supports a specific interface.
    /// @param interfaceId The interface ID to check.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // TODO build getURI => from distributor custodian /erc721-metadata
    // TODO transfer ownership + fee
    // TODO: approved content get an incentive: a cooling mechanism is needed eg:
    // log decay, max registered asset rate, etc

    /// @notice Mints a new NFT representing an asset to the specified address.
    /// @dev The assumption is that only those who know the asset ID
    /// and have the required approval can mint the corresponding token.
    /// @param to The address to mint the NFT to.
    /// @param assetId The unique identifier for the asset, which serves as the NFT ID.
    function registerAsset(address to, uint256 assetId) external onlyApprovedAsset(to, assetId) {
        _mint(to, assetId); // register asset as 721 token
        emit RegisteredAsset(to, assetId);
    }

    /// @dev Internal function to update the ownership of a token.
    /// @param to The address to transfer the token to.
    /// @param tokenId The ID of the token to transfer.
    /// @param auth The address authorized to perform the transfer.
    /// @return The address of the new owner of the token.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /// @dev Internal function to increase the balance of an account.
    /// @param account The address of the account whose balance is to be increased.
    /// @param value The amount by which the balance is to be increased.
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
