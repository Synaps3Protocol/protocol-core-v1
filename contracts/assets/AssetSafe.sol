// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { IAssetOwnership } from "@synaps3/core/interfaces/assets/IAssetOwnership.sol";
import { IAssetSafe } from "@synaps3/core/interfaces/assets/IAssetSafe.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @title AssetSafe
/// @notice A secure storage contract for complementary asset data.
/// @dev This contract does not store the actual asset but rather manages metadata, access points,
///      encrypted keys, licenses, passwords, and other sensitive information required to control asset access.
contract AssetSafe is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IAssetSafe {
    /// Rationale: Our immutables behave as constants after deployment
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// slither-disable-next-line naming-convention
    IAssetOwnership public immutable ASSET_OWNERSHIP;

    /// @dev Mapping to securely store encrypted content using a unique key derived from assetId and cipher type.
    mapping(bytes32 => bytes) private _secured;

    /// @dev Mapping to associate an asset ID with its assigned cipher type (encryption scheme).
    mapping(uint256 => T.Cipher) private _schemes;

    /// @dev Event emitted when encrypted content is successfully stored with a cipher type.
    /// @param assetId The unique identifier of the asset whose content was stored.
    /// @param holder The address of the account that owns or manages the asset content.
    /// @param cipherType The type of cipher used to store the content.
    event ContentStored(uint256 indexed assetId, address indexed holder, T.Cipher cipherType);

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
        _disableInitializers();
        ASSET_OWNERSHIP = IAssetOwnership(AssetOwnership);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Retrieves the "safe" scheme type associated with a given asset ID.
    /// @param assetId The identifier of the asset.
    /// @return The cipher type used for the asset.
    function getType(uint256 assetId) external view returns (T.Cipher) {
        return _schemes[assetId];
    }

    /// @notice Retrieves the encrypted content for a given asset.
    /// @dev Returns the stored data associated with an asset ID and its cipher type.
    /// @param assetId The unique identifier of the asset.
    /// @param cipherType The cipher type used (e.g., LIT, RSA, EC).
    /// @return The encrypted content stored in bytes format.
    function getContent(uint256 assetId, T.Cipher cipherType) external view returns (bytes memory) {
        bytes32 key = _computeComposedKey(assetId, cipherType);
        return _secured[key];
    }

    /// @notice Stores encrypted content with a specific cipher type.
    /// @dev Only the asset owner can store content. The encryption scheme is recorded for proper decryption.
    /// @param assetId The unique identifier of the asset.
    /// @param cipherType The cipher type used for securing the content.
    /// @param data The encrypted content, represented as a byte array.
    function setContent(uint256 assetId, T.Cipher cipherType, bytes memory data) external onlyHolder(assetId) {
        bytes32 key = _computeComposedKey(assetId, cipherType);
        _secured[key] = data; // store the encrypted content.
        _schemes[assetId] = cipherType; // associate the asset with the cipher type.
        emit ContentStored(assetId, msg.sender, cipherType);
    }

    /// @notice Authorizes contract upgrades, ensuring only the admin can initiate upgrades.
    /// @param newImplementation The address of the new contract implementation.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Computes a unique key for securely storing encrypted content.
    /// @dev Uses keccak256 hashing to combine assetId and cipher type into a unique identifier.
    /// @param assetId The ID of the asset.
    /// @param cipherType The cipher type used.
    /// @return A unique key derived from the assetId and cipher type.
    function _computeComposedKey(uint256 assetId, T.Cipher cipherType) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(assetId, cipherType));
    }
}
