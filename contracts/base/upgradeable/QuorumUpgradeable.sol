// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title QuorumUpgradeable
 * @dev Abstract contract for managing registration status in a Finite State Machine (FSM).
 *
 *                Default
 *              (0: Pending)
 *                    |
 *                    v
 *                 Register
 *       ------ (1: Waiting) -------
 *      /              |            \
 *     v               v             v
 *    Quit          Approve        Block
 * (0: Pending)   (2: Active)   (3: Blocked)
 *                     |
 *                     v
 *                   Revoke
 *                (3: Blocked)
 */
abstract contract QuorumUpgradeable is Initializable {
    /// @notice Enum to represent the status of an entity.
    enum Status {
        Pending, // 0: The entity is default pending approval
        Waiting, // 1: The entity is waiting for approval
        Active, // 2: The entity is active
        Blocked // 3: The entity is blocked
    }

    /// @custom:storage-location erc7201:quorumupgradeable
    struct RegistryStorage {
        mapping(uint256 => Status) _status; // Mapping to store the status of entities
    }

    // ERC-7201: Namespaced Storage Layout to avoid storage layout errors
    // keccak256(abi.encode(uint256(keccak256("watchit.quorum.status")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REGISTRY_SLOT = 0x78a5d34d6f19765a8d11b74cebcafd0494288384b72923088bc4746147d1ae00;

    /// @notice Error to be thrown when an entity is inactive.
    error InvalidInactiveState();
    /// @notice Error to be thrown when an entity is already pending approval.
    error AlreadyPendingApproval();
    /// @notice Error to be thrown when an entity is not waiting for approval.
    error NotWaitingApproval();

    /// @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    /// This is the method to initialize this contract and any other extended contracts.
    function __Quorum_init() internal onlyInitializing {}

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    /// This is the method to initialize this contract as standalone.
    function __Quorum_init_unchained() internal onlyInitializing {}

    /// @notice Internal function to get the status of an entity.
    /// @param entry The ID of the entity.
    function _status(uint256 entry) internal view returns (Status) {
        RegistryStorage storage $ = _getRegistryStorage();
        return $._status[entry];
    }

    /// @notice Internal function to revoke an entity's approval status.
    /// @dev This operation should only be called after the entry has been approved.
    /// @param entry The ID of the entity.
    function _revoke(uint256 entry) internal {
        RegistryStorage storage $ = _getRegistryStorage();
        if (_status(entry) != Status.Active) revert InvalidInactiveState();
        $._status[entry] = Status.Blocked;
    }

    /// @notice Internal function to block an entity before approval.
    /// @dev This operation should be called when the entry is in a pending state, before being approved.
    /// @param entry The ID of the entity.
    function _block(uint256 entry) internal {
        RegistryStorage storage $ = _getRegistryStorage();
        if (_status(entry) != Status.Waiting) revert NotWaitingApproval();
        $._status[entry] = Status.Blocked;
    }

    /// @notice Internal function to approve an entity's access.
    /// @param entry The ID of the entity.
    function _approve(uint256 entry) internal {
        RegistryStorage storage $ = _getRegistryStorage();
        if (_status(entry) != Status.Waiting) revert NotWaitingApproval();
        $._status[entry] = Status.Active;
    }

    /// @notice Internal function for an entity to resign.
    /// @param entry The ID of the entity.
    function _quit(uint256 entry) internal {
        RegistryStorage storage $ = _getRegistryStorage();
        if (_status(entry) != Status.Waiting) revert NotWaitingApproval();
        $._status[entry] = Status.Pending;
    }

    /// @notice Internal function to start an entity's registration.
    /// @param entry The ID of the entity.
    function _register(uint256 entry) internal {
        RegistryStorage storage $ = _getRegistryStorage();
        if (_status(entry) != Status.Pending) revert AlreadyPendingApproval();
        $._status[entry] = Status.Waiting;
    }

    /// @notice Internal function to get the registry storage.
    function _getRegistryStorage() private pure returns (RegistryStorage storage $) {
        assembly {
            $.slot := REGISTRY_SLOT
        }
    }
}
