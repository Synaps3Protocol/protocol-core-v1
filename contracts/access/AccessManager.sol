// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";

import { C } from "contracts/libraries/Constants.sol";

/// @title AccessManager
/// @dev Manages roles and permissions across the protocol.
contract AccessManager is Initializable, UUPSUpgradeable, AccessControlUpgradeable, IAccessManager {
    address private _governor;

    /// @notice Event emitted when a role is granted to an account.
    /// @param account The address of the account that has been granted the role.
    /// @param role The role granted to the account.
    event RoleGranted(address indexed account, bytes32 role);

    /// @notice Event emitted when a role is revoked from an account.
    /// @param account The address of the account that has had the role revoked.
    /// @param role The role revoked from the account.
    event RoleRevoked(address indexed account, bytes32 role);

    /// @dev Modifier that checks if the caller has the DEFAULT_ADMIN_ROLE.
    modifier onlyAdmin() {
        _checkRole(C.ADMIN_ROLE);
        _;
    }

    /// @dev Modifier that checks if the caller has the GOV_ROLE.
    modifier onlyGov() {
        _checkRole(C.GOV_ROLE);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the AccessManager contract and assigns the ADMIN_ROLE to the deployer.
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(C.ADMIN_ROLE, msg.sender);
    }

    /// @notice Returns the current governor address.
    /// @return The address of the current governor.
    function getGovernor() external view returns (address) {
        return _governor;
    }

    /// @notice Sets the governance address.
    /// @dev Only callable by an account with DEFAULT_ADMIN_ROLE.
    /// @param governor The address to set as the new governor.
    function setGovernor(address governor) external onlyAdmin {
        _grantRole(C.GOV_ROLE, governor);
        _governor = governor;
    }

    /// @notice Grants a specific role to an account.
    /// @param account The address of the account to grant the role to.
    /// @param role The role to be granted.
    /// @dev Only governance is allowed to grant roles.
    function grantRole(
        bytes32 role,
        address account
    ) public override(IAccessControl, AccessControlUpgradeable) onlyGov {
        _grantRole(role, account);
        emit RoleGranted(account, role);
    }

    /// @notice Revokes a specific role from an account.
    /// @param account The address of the account to revoke the role from.
    /// @param role The role to be revoked.
    /// @dev Only governance is allowed to revoke roles.
    function revokeRole(
        bytes32 role,
        address account
    ) public override(IAccessControl, AccessControlUpgradeable) onlyGov {
        _revokeRole(role, account);
        emit RoleRevoked(account, role);
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the admin can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
