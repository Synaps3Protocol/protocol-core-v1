// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC721Stateful } from "@synaps3/core/interfaces/token/erc721/IERC721Stateful.sol";

/// @title ERC721StatefulUpgradeable
/// @dev An upgradeable contract that adds state management to ERC721 tokens.
/// It allows tokens to have two states: Inactive and Active.
abstract contract ERC721StatefulUpgradeable is Initializable, IERC721Stateful {
    /// @custom:storage-location erc7201:erc721stateful
    /// @notice Storage structure to track asset states by token ID.
    struct ERC721StateStorage {
        mapping(uint256 => bool) _state;
    }

    /// @dev Storage slot for LedgerStorage, calculated using a unique namespace to avoid conflicts.
    /// The `STATE_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant STATE_SLOT = 0x324a9a77402a1e94df4d893f8dc6150d3318bb54d8228d276535d523c0ac8100;

    /// @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    /// This is the method to initialize this contract and any other extended contracts.
    function __ERC721Stateful_init() internal onlyInitializing {}

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    /// This is the method to initialize this contract as standalone.
    function __ERC721Stateful_init_unchained() internal onlyInitializing {}

    /// @dev Internal function to set the state of a token to Active.
    /// @param tokenId The ID of the token to activate.
    function _activate(uint256 tokenId) internal {
        ERC721StateStorage storage $ = _getERC721StateStorage();
        $._state[tokenId] = true;
    }

    /// @dev Internal function to set the state of a token to Inactive.
    /// @param tokenId The ID of the token to deactivate.
    function _deactivate(uint256 tokenId) internal {
        ERC721StateStorage storage $ = _getERC721StateStorage();
        $._state[tokenId] = false;
    }

    /// @notice Check if a token is in an active state.
    /// @param tokenId The ID of the token to query.
    /// @return True if the token is active, false otherwise.
    function isActive(uint256 tokenId) public view returns (bool) {
        ERC721StateStorage storage $ = _getERC721StateStorage();
        return $._state[tokenId] == true;
    }

    /// @notice Internal function to get the registry storage.
    function _getERC721StateStorage() private pure returns (ERC721StateStorage storage $) {
        assembly {
            $.slot := STATE_SLOT
        }
    }
}
