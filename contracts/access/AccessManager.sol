// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagerUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import { C } from "@synaps3/core/primitives/Constants.sol";

/// @title AccessManager
/// @notice Manages roles and permissions across the Synapse protocol.
/// @dev Implements OpenZeppelin's `AccessManagerUpgradeable` with a structured role hierarchy.
///      Uses a UUPS (Universal Upgradeable Proxy Standard) mechanism for upgradeability.
contract AccessManager is Initializable, UUPSUpgradeable, AccessManagerUpgradeable {
    /// @notice Initializes the proxy state.
    function initialize(address initialAdmin) public override initializer {
        __UUPSUpgradeable_init();
        __AccessManager_init(initialAdmin);

        // Initially all the the roles are managed by admin
        // since gov role has not role admin set, admin is by default
        // based on default values for _roles struct mapping(uint64 roleId => Role) _roles;
        // any not granted nor found _roles[roleId] = Role({admin: 0, ...}).

        // contracts/access/manager/AccessManagerUpgradeable.sol#L697
        // contracts/access/manager/AccessManagerUpgradeable.sol#L738C8-L738C100
        // if (selector == this.grantRole.selector || selector == this.revokeRole.selector) {
        //     // First argument is a roleId.
        //     uint64 roleId = abi.decode(data[0x04:0x24], (uint64));
        //     return (true, getRoleAdmin(roleId), 0); // => (true, 0, 0)
        // }

        _setRoleAdmin(C.MOD_ROLE, C.ADMIN_ROLE);
        _setRoleAdmin(C.OPS_ROLE, C.ADMIN_ROLE);
        _setRoleAdmin(C.VER_ROLE, C.GOV_ROLE);
    }

    // TODO pause protocol based on permission and roles

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the admin can authorize the upgrade.
    function _authorizeUpgrade(address) internal view override {
        (bool isMember, ) = hasRole(C.ADMIN_ROLE, msg.sender);
        // solhint-disable-next-line gas-custom-errors
        require(isMember, "Only admin can authorize the upgrade");
    }
}
