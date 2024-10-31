// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IGovernable } from "contracts/interfaces/IGovernable.sol";
import { C } from "contracts/libraries/Constants.sol";

/// @title GovernableUpgradeable
/// @dev Abstract contract that provides governance functionality to upgradeable contracts.
/// It inherits from IGovernable and AccessControlUpgradeable.
abstract contract GovernableUpgradeable is Initializable, AccessControlUpgradeable, IGovernable {
    /// @custom:storage-location erc7201:governableupgradeable
    struct GovernorStorage {
        address _governor;
    }

    /// @dev Storage slot for LedgerStorage, calculated using a unique namespace to avoid conflicts.
    /// The `GOVERNOR_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant GOVERNOR_SLOT = 0xb8e950798a2a06a6f5727a94041b193569f4f67d69a0de3cf866d93822e7fa00;

    /// @dev Modifier that checks if the caller has the GOB_ROLE.
    modifier onlyGov() {
        _checkRole(C.GOV_ROLE);
        _;
    }

    /// @dev Modifier that checks if the caller has the MOD_ROLE.
    modifier onlyMod() {
        _checkRole(C.MOD_ROLE);
        _;
    }

    /// @dev Modifier that checks if the caller has the DEFAULT_ADMIN_ROLE.
    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    /// @notice Sets the governance address.
    /// @dev Only callable by the DEFAULT_ADMIN_ROLE.
    /// @param newGovernance The address to set as the new governor.
    function setGovernance(address newGovernance) external onlyAdmin {
        GovernorStorage storage $ = _getGovernorStorage();
        _grantRole(C.GOV_ROLE, newGovernance);
        $._governor = newGovernance;
    }

    /// @notice Sets the emergency admin address.
    /// @dev Only callable by the GOB_ROLE.
    /// @param newEmergencyAdmin The address to set as the new emergency admin.
    function setEmergencyAdmin(address newEmergencyAdmin) external onlyGov {
        _grantRole(DEFAULT_ADMIN_ROLE, newEmergencyAdmin);
    }

    /// @notice Revokes the emergency admin role from the specified address.
    /// @dev Only callable by the GOB_ROLE.
    /// @param revokedAddress The address to revoke the emergency admin role from.
    function revokeEmergencyAdmin(address revokedAddress) external onlyGov {
        _revokeRole(DEFAULT_ADMIN_ROLE, revokedAddress);
    }

    /// @notice Returns the current governor address.
    function getGovernance() external view returns (address) {
        GovernorStorage storage $ = _getGovernorStorage();
        return $._governor;
    }

    function __Governable_init(address initialAdmin) internal onlyInitializing {
        __Governable_init_unchained(initialAdmin);
    }

    function __Governable_init_unchained(address initialAdmin) internal onlyInitializing {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    ///@notice Internal function to get the governor storage.
    function _getGovernorStorage() private pure returns (GovernorStorage storage $) {
        assembly {
            $.slot := GOVERNOR_SLOT
        }
    }
}
