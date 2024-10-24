// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IGovernable } from "contracts/interfaces/IGovernable.sol";
import { C } from "contracts/libraries/Constants.sol";

/// @title GovernableU
/// @dev Abstract contract that provides governance functionality to contracts.
/// @notice This contract manages roles for governance, moderators, and admin permissions.
abstract contract Governable is AccessControl, IGovernable {
    /// @notice Address of the current governor.
    address governor;

    /// @dev Modifier that checks if the caller has the GOB_ROLE (Governor Role).
    modifier onlyGov() {
        _checkRole(C.GOV_ROLE);
        _;
    }

    /// @dev Modifier that checks if the caller has the MOD_ROLE (Moderator Role).
    modifier onlyMod() {
        _checkRole(C.MOD_ROLE);
        _;
    }

    /// @dev Modifier that checks if the caller has the DEFAULT_ADMIN_ROLE (Admin Role).
    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    /// @notice Constructor to set the initial admin of the contract.
    /// @param initialAdmin The address to be granted the DEFAULT_ADMIN_ROLE.
    constructor(address initialAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /// @notice Sets the governance address (Governor Role).
    /// @dev Only callable by the address with DEFAULT_ADMIN_ROLE.
    /// @param newGovernance The address to set as the new governor.
    function setGovernance(address newGovernance) external onlyAdmin {
        _grantRole(C.GOV_ROLE, newGovernance);
        governor = newGovernance;
    }

    /// @notice Sets the emergency admin address (Admin Role).
    /// @dev Only callable by the address with the GOB_ROLE.
    /// @param newEmergencyAdmin The address to set as the new emergency admin.
    function setEmergencyAdmin(address newEmergencyAdmin) external onlyGov {
        _grantRole(DEFAULT_ADMIN_ROLE, newEmergencyAdmin);
    }

    /// @notice Revokes the emergency admin role from a specified address.
    /// @dev Only callable by the address with the GOB_ROLE.
    /// @param revokedAddress The address from which the emergency admin role will be revoked.
    function revokeEmergencyAdmin(address revokedAddress) external onlyGov {
        _revokeRole(DEFAULT_ADMIN_ROLE, revokedAddress);
    }

    /// @notice Returns the current governor address.
    /// @return The address of the current governor.
    function getGovernance() external view returns (address) {
        return governor;
    }
}
