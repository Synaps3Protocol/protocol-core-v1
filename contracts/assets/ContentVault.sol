// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { IContentOwnership } from "contracts/interfaces/assets/IContentOwnership.sol";
import { IContentVault } from "contracts/interfaces/assets/IContentVault.sol";

/// @title ContentVault
/// @notice This contract stores encrypted content and ensures only the rightful
/// content holder can access or modify the content.
contract ContentVault is Initializable, UUPSUpgradeable, GovernableUpgradeable, IContentVault {
    /// Preventing accidental/malicious changes during contract reinitializations.
    IContentOwnership public immutable CONTENT_OWNSERSHIP;
    /// @dev Mapping to store encrypted content, identified by content ID.
    mapping(uint256 => bytes) private secured;
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
    constructor(address contentOwnership) {
        ///  https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to verify ownership during content storage handling
        CONTENT_OWNSERSHIP = IContentOwnership(contentOwnership);
    }

    /// @notice Initializes the proxy state.
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
    }

    /// @notice Retrieves the encrypted content for a given content ID.
    /// @param contentId The identifier of the content.
    /// @dev This function is used to access encrypted data stored in the vault,
    /// which can include various types of encrypted information such as LIT chain data or shared key-encrypted data.
    function getContent(uint256 contentId) public view returns (bytes memory) {
        // In common scenarios, only custodians are allowed to access the secured content.
        // However, this does not prevent access since all data on a smart contract is publicly readable.
        return secured[contentId];
    }

    /// @notice Stores encrypted content in the vault under a specific content ID.
    /// @param contentId The identifier of the content.
    /// @param encryptedContent The encrypted content to store, represented as bytes.
    /// @dev Only the rightful content holder can set or modify the content.
    /// This allows for dynamic secure storage, handling encrypted data like public key encrypted content or
    /// hash-encrypted data.
    function setContent(uint256 contentId, bytes memory encryptedContent) public onlyHolder(contentId) {
        secured[contentId] = encryptedContent;
    }

    // TODO tests
    // TODO dejar directo LIT? permitir multiples alg? establecer por un enum los tipos?

    /// @notice Function that authorizes the contract upgrade. It ensures that only the admin
    /// can authorize a contract upgrade to a new implementation.
    /// @param newImplementation The address of the new contract implementation.
    /// @dev Overrides the `_authorizeUpgrade` function from UUPSUpgradeable to enforce admin-only
    /// access for upgrades.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
