// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
// solhint-disable-next-line max-line-length
import { ERC721EnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { AccessControlledUpgradeable } from "contracts/base/upgradeable/AccessControlledUpgradeable.sol";
import { IContentVerifiable } from "contracts/interfaces/content/IContentVerifiable.sol";
import { IContentOwnership } from "contracts/interfaces/content/IContentOwnership.sol";

// TODO imp ERC404
// TODO imp EIP4337 accounting

/// @title Ownership ERC721 Upgradeable
/// @notice This abstract contract manages the ownership.
contract ContentOwnership is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    AccessControlledUpgradeable,
    ERC721EnumerableUpgradeable,
    IContentOwnership
{
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IContentVerifiable public immutable CONTENT_REFERENDUM;

    /// @dev Emitted when a new content item is registered on the platform.
    /// @param owner The address of the content creator or owner who registered the content.
    /// @param contentId The unique identifier for the registered content.
    event RegisteredContent(address indexed owner, uint256 contentId);

    /// @dev Error indicating that an operation attempted to reference content that has not been approved.
    /// This error is triggered when the content being accessed or referenced is not in an approved state.
    error InvalidNotApprovedContent();

    /// @notice Modifier to ensure content is approved before distribution.
    /// @param to The address attempting to distribute the content.
    /// @param contentId The ID of the content to be distributed.
    /// @dev The content must be approved by referendum or the recipient must have a verified role.
    /// This modifier checks if the content is approved by referendum or if the recipient has a verified role.
    /// It also ensures that the recipient is the one who initially submitted the content for approval.
    modifier onlyApprovedContent(address to, uint256 contentId) {
        // Revert if the content is not approved or if the recipient is not the original submitter
        if (!CONTENT_REFERENDUM.isApproved(to, contentId)) {
            revert InvalidNotApprovedContent();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address contentReferendum) {
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        _disableInitializers();
        // we need to verify the status of each content before allow register it.
        CONTENT_REFERENDUM = IContentVerifiable(contentReferendum);
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

    /// @notice Mints a new NFT to the specified address.
    /// @dev Our naive assumption is that only those who know the content id can mint the corresponding token.
    /// @param to The address to mint the NFT to.
    /// @param contentId The content id of the NFT. This should be a unique identifier for the NFT.
    function registerContent(address to, uint256 contentId) external onlyApprovedContent(to, contentId) {
        _mint(to, contentId);
        emit RegisteredContent(to, contentId);
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
