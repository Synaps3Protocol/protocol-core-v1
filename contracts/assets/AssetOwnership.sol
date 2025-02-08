// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
// solhint-disable-next-line max-line-length
import { ERC721EnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { ERC721StatefulUpgradeable } from "@synaps3/core/primitives/upgradeable/ERC721StatefulUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { IAssetVerifiable } from "@synaps3/core/interfaces/assets/IAssetVerifiable.sol";
import { IAssetOwnership } from "@synaps3/core/interfaces/assets/IAssetOwnership.sol";

// TODO: Evaluate ERC-404 for fractionalization support
// TODO: Evaluate ERC-2981 for royalty management
// TODO: Evaluate ERC-4804 for URL-based on-chain asset references

/// @title AssetOwnership
/// @notice This contract manages ownership and lifecycle of digital assets using ERC721.
/// @dev Implements UUPS upgradeability, access control, and stateful asset management.
contract AssetOwnership is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    AccessControlledUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721StatefulUpgradeable,
    IAssetOwnership
{
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// @notice Reference to the asset verification contract for content approval.
    IAssetVerifiable public immutable AssetReferendum;

    /// @dev Emitted when a new asset is registered on the platform.
    /// @param owner The address of the creator or owner of the registered asset.
    /// @param assetId The unique identifier for the registered asset.
    event RegisteredAsset(address indexed owner, uint256 assetId);

    /// @dev Emitted when an asset is revoked and removed from the platform.
    /// @param owner The address of the owner of the revoked asset.
    /// @param assetId The unique identifier for the revoked asset.
    event RevokedAsset(address indexed owner, uint256 assetId);

    /// @dev Emitted when an asset is transferred from one owner to another.
    /// @param from The address of the current owner of the asset.
    /// @param to The address of the new owner of the asset.
    /// @param assetId The unique identifier for the transferred asset.
    event TransferredAsset(address indexed from, address indexed to, uint256 assetId);

    /// @notice Emitted when an asset is enabled.
    /// @param tokenId The ID of the token that was enabled.
    event AssetEnabled(uint256 indexed tokenId);

    /// @notice Emitted when an asset is disabled.
    /// @param tokenId The ID of the token that was disabled.
    event AssetDisabled(uint256 indexed tokenId);

    /// @dev Error indicating that an operation attempted to reference content that has not been approved.
    error InvalidNotApprovedAsset();

    /// @notice Ensures the asset is approved before allowing distribution.
    /// @param to The address attempting to distribute the asset.
    /// @param assetId The ID of the asset to be distributed.
    /// @dev The asset must be approved via referendum or the recipient must hold a verified role.
    modifier onlyApprovedAsset(address to, uint256 assetId) {
        if (!AssetReferendum.isApproved(to, assetId)) {
            revert InvalidNotApprovedAsset();
        }
        _;
    }

    /// @notice Ensures that only the asset owner can perform certain operations.
    /// @param assetId The ID of the asset being modified.
    modifier onlyOwner(uint256 assetId) {
        if (ownerOf(assetId) != msg.sender) {
            revert InvalidUnauthorizedOperation("Only the asset owner can modify its state.");
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @notice Disables initializers for security reasons in UUPS upgradeable contracts.
    constructor(address assetReferendum) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to verify that asset has passed the community approval.
        AssetReferendum = IAssetVerifiable(assetReferendum);
    }

    /// @notice Initializes the upgradeable contract.
    /// @param accessManager Address of the access control manager.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __ERC721Enumerable_init();
        __ERC721Stateful_init();
        __ERC721_init("SynapseIP", "SYN");
        __AccessControlled_init(accessManager);
    }

    /// @notice Checks if the contract supports a specific ERC standard interface.
    /// @param interfaceId The interface ID to check.
    /// @return True if the contract supports the given interface.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // TODO: build getURI => from distributor custodian /erc721-metadata
    // TODO: transfer ownership fee
    // TODO: approved content get an incentive: a cooling mechanism is needed eg:
    // log decay, max registered asset rate, etc

    /// @notice Registers a new asset as an ERC721 NFT.
    /// @dev Requires approval before an asset can be registered.
    /// @param to The address that will own the minted NFT.
    /// @param assetId The unique identifier for the asset, serving as the NFT ID.
    function register(address to, uint256 assetId) external onlyApprovedAsset(to, assetId) {
        _mint(to, assetId);
        _enableAsset(assetId);
        emit RegisteredAsset(to, assetId);
    }

    /// @notice Revokes an asset, permanently disabling it within the system.
    /// @dev This action is irreversible and restricted to governance control.
    /// @param assetId The unique identifier of the asset to be revoked.
    function revoke(uint256 assetId) external restricted {
        address owner = ownerOf(assetId);
        _burn(assetId);
        _disableAsset(assetId);
        emit RevokedAsset(owner, assetId);
    }

    /// @notice Transfers an asset to a new owner.
    /// @param to The address of the new owner.
    /// @param assetId The unique identifier of the asset being transferred.
    function transfer(address to, uint256 assetId) external {
        _transfer(msg.sender, to, assetId);
        emit TransferredAsset(msg.sender, to, assetId);
    }

    /// @notice Switches the activation state of an asset.
    /// @dev If the asset is active, it becomes inactive; if inactive, it becomes active.
    /// @param assetId The ID of the asset whose state is being changed.
    /// @return newState The updated state of the asset (`true` for active, `false` for inactive).
    function switchState(uint256 assetId) external onlyOwner(assetId) returns (bool newState) {
        bool isActiveState = isActive(assetId); // true or false
        // if isActive then deactivate else activate
        isActiveState ? _disableAsset(assetId) : _enableAsset(assetId);
        // set newState to false if isActive otherwise set true to active
        newState = !isActiveState;
    }

    /// @dev Internal function to update ownership when transferring a token.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /// @dev Internal function to adjust account balances upon transfers.
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    /// @notice Ensures only the administrator can authorize contract upgrades.
    /// @param newImplementation Address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @dev Internal function to enable an asset.
    function _enableAsset(uint256 assetId) private {
        _activate(assetId);
        emit AssetEnabled(assetId);
    }

    /// @dev Internal function to disable an asset.
    function _disableAsset(uint256 assetId) private {
        _deactivate(assetId);
        emit AssetDisabled(assetId);
    }
}
