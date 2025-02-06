// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IAccessManager } from "@synaps3/core/interfaces/access/IAccessManager.sol";
import { C } from "@synaps3/core/primitives/Constants.sol";

/// @title AccessControlledUpgradeable
/// @dev Abstract contract that provides role-based access control functionality to upgradeable contracts.
/// This contract requires an AccessManager to manage roles.
abstract contract AccessControlledUpgradeable is Initializable, AccessManagedUpgradeable {
    /// @custom:storage-location erc7201:accesscontrolledupgradeable
    struct AccessControlStorage {
        address _accessManager;
    }

    /// @dev Storage slot for AccessControlStorage, calculated using a unique namespace to avoid conflicts.
    /// The `ACCESS_MANAGER_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant ACCESS_MANAGER_SLOT = 0xb8e950798a2a06a6f5727a94041b193569f4f67d69a0de3cf866d93822e7fa00;

    /// @dev Error thrown when an unauthorized operation is attempted.
    error InvalidUnauthorizedOperation(string);

    /// @dev Modifier that checks if the caller has the DEFAULT_ADMIN_ROLE.
    modifier onlyAdmin() {
        // !WARNING The restricted modifier should never be used on internal functions,
        // judiciously used in public functions,  and ideally only used in external functions.
        // See restricted:
        // -> Since we can't use the `restricted` modifier and we still need to check the admin role..
        if (!_hasRole(C.ADMIN_ROLE, msg.sender)) {
            revert InvalidUnauthorizedOperation("Only admin can perform this action.");
        }
        _;
    }

    // @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    /// This is the method to initialize this contract and any other extended contracts.
    /// @param accessManager The address of the AccessManager contract.
    /// slither-disable-next-line naming-convention
    function __AccessControlled_init(address accessManager) internal onlyInitializing {
        __AccessManaged_init(accessManager);
        __AccessControlled_init_unchained(accessManager);
    }

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    /// This is the method to initialize this contract as standalone.
    /// slither-disable-next-line naming-convention
    function __AccessControlled_init_unchained(address accessManager) internal onlyInitializing {
        if (accessManager == address(0)) {
            revert InvalidUnauthorizedOperation("Invalid authority address.");
        }

        AccessControlStorage storage $ = _getAccessControlStorage();
        $._accessManager = accessManager;
    }

    /// @notice Checks if an account has a specific role.
    /// @param role The role to check.
    /// @param account The address of the account.
    /// @return bool True if the account has the role, false otherwise.
    function _hasRole(uint64 role, address account) internal view returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        IAccessManager manager = IAccessManager($._accessManager);
        (bool isMember, uint256 executionDelay) = manager.hasRole(role, account);
        return isMember && executionDelay == 0; // immediately execution authorization for admin
    }

    ///@notice Internal function to access the AccessControlStorage.
    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := ACCESS_MANAGER_SLOT
        }
    }
}
