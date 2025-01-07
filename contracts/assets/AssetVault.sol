// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { IAssetOwnership } from "@synaps3/core/interfaces/assets/IAssetOwnership.sol";
import { IAssetVault } from "@synaps3/core/interfaces/assets/IAssetVault.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @notice This contract is designed as a secure and decentralized area to exchange complementary data related to
/// content access, such as encrypted keys, license keys, or metadata. It does not store the actual content itself,
/// but manages the complementary data necessary to access that content.
contract AssetVault is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IAssetVault {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAssetOwnership public immutable ASSET_OWNERSHIP;

    /// @dev Mapping to store encrypted content, identified by content ID.
    mapping(uint256 => mapping(T.VaultType => bytes)) private _secured;

    /// @dev Event emitted when encrypted content is successfully stored in a vault.
    /// @param assetId The unique identifier of the asset whose content was stored.
    /// @param holder The address of the account that owns or manages the asset content.
    /// @param vault The type of vault where the content is stored.
    event ContentStored(uint256 indexed assetId, address indexed holder, T.VaultType vault);

    /// @notice Error thrown when a non-owner tries to modify or access the asset.
    error InvalidAssetRightsHolder();

    /// @notice Modifier that restricts access to the asset holder only.
    /// @param assetId The identifier of the asset.
    /// @dev Reverts if the sender is not the owner of the asset based on the Ownership contract.
    modifier onlyHolder(uint256 assetId) {
        if (ASSET_OWNERSHIP.ownerOf(assetId) != msg.sender) {
            revert InvalidAssetRightsHolder();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address AssetOwnership) {
        ///  https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to verify ownership during content storage handling
        ASSET_OWNERSHIP = IAssetOwnership(AssetOwnership);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Retrieves the encrypted content for a given content ID.
    /// @param assetId The identifier of the asset.
    /// @param vault The vault type used to retrieve the asset (e.g., LIT, RSA, EC).
    function getContent(uint256 assetId, T.VaultType vault) external view returns (bytes memory) {
        return _secured[assetId][vault];
    }

    /// @notice Stores encrypted content in the vault under a specific content ID.
    /// @param assetId The identifier of the asset.
    /// @param vault The vault type to associate with the encrypted content (e.g., LIT, RSA, EC).
    /// @param data The secure content to store, represented as bytes.
    function setContent(uint256 assetId, T.VaultType vault, bytes memory data) external onlyHolder(assetId) {
        _secured[assetId][vault] = data;
        emit ContentStored(assetId, msg.sender, vault);
    }

    /// @notice Function that authorizes the contract upgrade. It ensures that only the admin
    /// can authorize a contract upgrade to a new implementation.
    /// @param newImplementation The address of the new contract implementation.
    /// @dev Overrides the `_authorizeUpgrade` function from UUPSUpgradeable to enforce admin-only
    /// access for upgrades.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
