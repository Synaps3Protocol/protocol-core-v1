// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IReferendumRoleManager
/// @notice Interface to manage roles for a referendum system, allowing accounts to be granted or revoked the "verified" role.
/// @dev This interface is intended to be implemented by contracts that handle role management in a referendum or governance system.
interface IReferendumRoleManager {
    /// @notice Grants the verified role to a specific account.
    /// @param account The address of the account to grant the verified role.
    function grantVerifiedRole(address account) external;

    /// @notice Revokes the verified role from a specific account.
    /// @param account The address of the account from which to revoke the verified role.
    function revokeVerifiedRole(address account) external;
}
