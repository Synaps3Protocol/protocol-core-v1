// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IContentRoleManager
/// @notice Interface to manage roles, allowing accounts to be granted or revoked.
interface IContentRoleManager {
    /// @notice Grants the verified role to a specific account.
    /// @param account The address of the account to grant the verified role.
    function grantVerifiedRole(address account) external;

    /// @notice Revokes the verified role from a specific account.
    /// @param account The address of the account from which to revoke the verified role.
    function revokeVerifiedRole(address account) external;
}
