// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IGovernable } from "contracts/interfaces/IGovernable.sol";

/// @title GovernableUpgradeable
/// @dev Abstract contract that provides governance functionality to upgradeable contracts.
/// It inherits from IGovernable and AccessControlUpgradeable.
abstract contract GovernableUpgradeable is Initializable, AccessControlUpgradeable, IGovernable {
    /// @custom:storage-location erc7201:governableupgradeable
    struct GovernorStorage {
        address _governor;
    }

    /// @notice The keccak256 hash representing the governance role.
    /// @dev This constant is used to identify accounts with the governance permissions within the system.
    bytes32 private constant GOV_ROLE = keccak256("GOV_ROLE");
    /// @notice The keccak256 hash representing the moderator role.
    /// @dev This constant is used to identify accounts with the moderator permissions within the system.
    bytes32 private constant MOD_ROLE = keccak256("MOD_ROLE");
    // ERC-7201: Namespaced Storage Layout is another convention that can be used to avoid storage layout errors
    // keccak256(abi.encode(uint256(keccak256("watchit.governable.governor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GOVERNOR_SLOT = 0xbe22a97ce56bf984cece6021e328584abbd5b3cd394ccbe3b6884d525c48c400;

    /// @dev Modifier that checks if the caller has the GOB_ROLE.
    modifier onlyGov() {
        _checkRole(GOV_ROLE);
        _;
    }

    /// @dev Modifier that checks if the caller has the MOD_ROLE.
    modifier onlyMod() {
        _checkRole(MOD_ROLE);
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
        _grantRole(GOV_ROLE, newGovernance);
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
