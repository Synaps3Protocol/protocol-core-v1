// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC721EnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { IContentVerifiable } from "contracts/interfaces/assets/IContentVerifiable.sol";
import { IContentOwnership } from "contracts/interfaces/assets/IContentOwnership.sol";

// TODO imp ERC404

/// @title Ownership ERC721 Upgradeable
/// @notice This abstract contract manages the ownership.
contract ContentOwnership is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    GovernableUpgradeable,
    ERC721EnumerableUpgradeable,
    IContentOwnership
{
    IContentVerifiable public contentReferendum;
    event RegisteredContent(address indexed owner, uint256 contentId);
    error InvalidNotApprovedContent();
    /// @notice Modifier to ensure content is approved before distribution.
    /// @param to The address attempting to distribute the content.
    /// @param contentId The ID of the content to be distributed.
    /// @dev The content must be approved by referendum or the recipient must have a verified role.
    /// This modifier checks if the content is approved by referendum or if the recipient has a verified role.
    /// It also ensures that the recipient is the one who initially submitted the content for approval.
    modifier onlyApprovedContent(address to, uint256 contentId) {
        // Revert if the content is not approved or if the recipient is not the original submitter
        if (!contentReferendum.isApproved(to, contentId)) {
            revert InvalidNotApprovedContent();
        }
        _;
    }

    // 3- Las condiciones adicionales como acceso por país, etc! Deben ser dados en el IP register url,
    // si no tiene estas condiciones, simplemente no se validan..

    // Evaluar si al registrar el token en Watchit se puede hacer algo similar a lo que hace story con los token URI,

    // Cuando se haga mint, obtener la información del token originario, digamos que sea un NFT externo y hacer un
    // remint en nuestro contrato con los detalles del contrato origen?

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @notice This constructor prevents the implementation contract from being initialized.
    /// @dev See https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
    /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the given dependencies, including the Referendum contract for governance-related verifications.
    /// @param contentReferendum_ The address of the Content Referendum contract, which is responsible for verifying governance decisions related to content.
    /// @dev This function can only be called once during the contract's deployment. It sets up UUPS upgradeability,
    /// ERC721 token functionality, and governance mechanisms. The Referendum contract is linked to handle governance verifications.
    function initialize(address contentReferendum_) public initializer {
        __UUPSUpgradeable_init();
        __ERC721Enumerable_init();
        __ERC721_init("Ownership", "OWN");
        __Governable_init(msg.sender);
        // we need to verify the status of each content before allow register it.
        contentReferendum = IContentVerifiable(contentReferendum_);
    }

    /// @notice Checks if the contract supports a specific interface.
    /// @param interfaceId The interface ID to check.
    /// @return True if the contract supports the interface, false otherwise.
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165, ERC721Upgradeable, AccessControlUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
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
