// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { C } from "contracts/libraries/Constants.sol";

/// @title AccessControlledUpgradeable
/// @dev Abstract contract that provides role-based access control functionality to upgradeable contracts.
/// This contract requires an AccessManager to manage roles.
abstract contract AccessControlledUpgradeable is Initializable {
    /// @custom:storage-location erc7201:accesscontrolledupgradeable
    struct AccessControlStorage {
        address _accessManager;
    }

    /// @dev Storage slot for AccessControlStorage, calculated using a unique namespace to avoid conflicts.
    /// The `ACCESS_MANAGER_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant ACCESS_MANAGER_SLOT = 0xb8e950798a2a06a6f5727a94041b193569f4f67d69a0de3cf866d93822e7fa00;

    /// @dev Error thrown when an unauthorized operation is attempted.
    error InvalidUnauthorizedOperation(string);

    /// @dev Modifier that checks if the caller has a specific role.
    /// @param role The role to check.
    modifier onlyRole(bytes32 role) {
        if (!_hasRole(role, msg.sender)) {
            revert InvalidUnauthorizedOperation("Caller does not have required role.");
        }
        _;
    }

    /// @dev Modifier that checks if the caller has the GOV_ROLE.
    modifier onlyGov() {
        if (!_hasRole(C.GOV_ROLE, msg.sender)) {
            revert InvalidUnauthorizedOperation("Only governance can perform this action.");
        }
        _;
    }

    /// @dev Modifier that checks if the caller has the MOD_ROLE.
    modifier onlyMod() {
        if (!_hasRole(C.MOD_ROLE, msg.sender)) {
            revert InvalidUnauthorizedOperation("Only moderator can perform this action.");
        }
        _;
    }

    /// @dev Modifier that checks if the caller has the DEFAULT_ADMIN_ROLE.
    modifier onlyAdmin() {
        if (!_hasRole(C.ADMIN_ROLE, msg.sender)) {
            revert InvalidUnauthorizedOperation("Only admin can perform this action.");
        }
        _;
    }

    /// @notice Initializes the contract with a specified AccessManager address.
    /// @param accessManager The address of the AccessManager contract.
    function __AccessControlled_init(address accessManager) internal onlyInitializing {
        __AccessControlled_init_unchained(accessManager);
    }

    function __AccessControlled_init_unchained(address accessManager) internal onlyInitializing {
        AccessControlStorage storage $ = _getAccessControlStorage();
        $._accessManager = accessManager;
    }

    /// @notice Checks if an account has a specific role.
    /// @param role The role to check.
    /// @param account The address of the account.
    /// @return bool True if the account has the role, false otherwise.
    function _hasRole(bytes32 role, address account) internal view returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        IAccessManager manager = IAccessManager($._accessManager);
        return manager.hasRole(role, account);
    }

    ///@notice Internal function to access the AccessControlStorage.
    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := ACCESS_MANAGER_SLOT
        }
    }
}
