// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { AccessControlledUpgradeable } from "contracts/base/upgradeable/AccessControlledUpgradeable.sol";
import { IAssetOwnership } from "contracts/interfaces/assets/IAssetOwnership.sol";
import { IAssetVault } from "contracts/interfaces/assets/IAssetVault.sol";
import { T } from "contracts/libraries/Types.sol";

/// @notice This contract is designed as a secure and decentralized area to exchange complementary data related to
/// content access, such as encrypted keys, license keys, or metadata. It does not store the actual content itself,
/// but manages the complementary data necessary to access that content.
contract AssetVault is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IAssetVault {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAssetOwnership public immutable CONTENT_OWNSERSHIP;
    /// @dev Mapping to store encrypted content, identified by content ID.
    mapping(uint256 => mapping(T.VaultType => bytes)) private _secured;
    /// @notice Error thrown when a non-owner tries to modify or access the content.
    error InvalidContentHolder();

    /// @notice Modifier that restricts access to the content holder only.
    /// @param contentId The identifier of the content.
    /// @dev Reverts if the sender is not the owner of the content based on the Ownership contract.
    modifier onlyHolder(uint256 contentId) {
        if (CONTENT_OWNSERSHIP.ownerOf(contentId) != msg.sender) {
            revert InvalidContentHolder();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address AssetOwnership) {
        ///  https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to verify ownership during content storage handling
        CONTENT_OWNSERSHIP = IAssetOwnership(AssetOwnership);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Retrieves the encrypted content for a given content ID.
    /// @param contentId The identifier of the content.
    /// @param vault The vault type used to retrieve the content (e.g., LIT, RSA, EC).
    function getContent(uint256 contentId, T.VaultType vault) public view returns (bytes memory) {
        return _secured[contentId][vault];
    }

    /// @notice Stores encrypted content in the vault under a specific content ID.
    /// @param contentId The identifier of the content.
    /// @param vault The vault type to associate with the encrypted content (e.g., LIT, RSA, EC).
    /// @param data The secure content to store, represented as bytes.
    function setContent(uint256 contentId, T.VaultType vault, bytes memory data) public onlyHolder(contentId) {
        _secured[contentId][vault] = data;
    }

    /// @notice Function that authorizes the contract upgrade. It ensures that only the admin
    /// can authorize a contract upgrade to a new implementation.
    /// @param newImplementation The address of the new contract implementation.
    /// @dev Overrides the `_authorizeUpgrade` function from UUPSUpgradeable to enforce admin-only
    /// access for upgrades.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
