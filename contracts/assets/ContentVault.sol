// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { IContentOwnership } from "contracts/interfaces/assets/IContentOwnership.sol";
import { IContentVault } from "contracts/interfaces/assets/IContentVault.sol";

/// @title ContentVault
/// @notice This contract stores encrypted content and ensures only the rightful content holder
/// can access or modify the content. It is designed to be upgradeable through UUPS and governed by a
/// decentralized authority.
/// @dev The contract uses the OpenZeppelin UUPS (Universal Upgradeable Proxy Standard) upgrade mechanism
/// and inherits Governable for governance control.
contract ContentVault is Initializable, UUPSUpgradeable, GovernableUpgradeable, IContentVault {
    /// @notice The Ownership contract that tracks content holders.
    IContentOwnership public ownership;
    /// @dev Mapping to store encrypted content, identified by content ID.
    mapping(uint256 => bytes) private secured;
    /// @notice Error thrown when a non-owner tries to modify or access the content.
    error InvalidContentHolder();

    /// @notice Modifier that restricts access to the content holder only.
    /// @param contentId The identifier of the content.
    /// @dev Reverts if the sender is not the owner of the content based on the Ownership contract.
    modifier onlyHolder(uint256 contentId) {
        if (ownership.ownerOf(contentId) != msg.sender) revert InvalidContentHolder();
        _;
    }

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @notice This constructor prevents the implementation contract from being initialized.
    /// @dev See https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
    /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the necessary dependencies, including the Ownership contract.
    /// @param ownership_ The address of the Ownership contract, which manages ownership records and verification.
    /// @dev This function can only be called once during the contract's initialization. It sets up UUPS upgradeability
    /// mechanisms and governance controls, linking the Ownership contract for future use.
    function initialize(address ownership_) public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
        ownership = IContentOwnership(ownership_);
    }

    /// @notice Retrieves the encrypted content for a given content ID.
    /// @param contentId The identifier of the content.
    /// @return The encrypted content as bytes.
    /// @dev This function is used to access encrypted data stored in the vault,
    /// which can include various types of encrypted information such as LIT chain data or shared key-encrypted data.
    function getContent(uint256 contentId) public view returns (bytes memory) {
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

    /// @notice Function that authorizes the contract upgrade. It ensures that only the admin
    /// can authorize a contract upgrade to a new implementation.
    /// @param newImplementation The address of the new contract implementation.
    /// @dev Overrides the `_authorizeUpgrade` function from UUPSUpgradeable to enforce admin-only
    /// access for upgrades.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
