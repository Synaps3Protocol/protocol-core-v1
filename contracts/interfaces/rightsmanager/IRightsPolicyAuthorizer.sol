// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsPolicyAuthorizer
/// @notice Interface for authorizing and managing policies related to content rights.
/// @dev This interface allows content holders to authorize and revoke policies
/// that manage their content-related rights.
interface IRightsPolicyAuthorizer {
    /// @notice Retrieves all policies authorized by a specific content holder.
    /// @dev This function returns an array of policy addresses that have been granted rights by the holder.
    /// @param holder The address of the content rights holder whose authorized policies are being queried.
    function getAuthorizedPolicies(address holder) external view returns (address[] memory);

    /// @notice Checks if a specific policy contract has been authorized by a content holder.
    /// @dev Verifies if the specified policy has permission to manage rights for the given holder’s content.
    /// @param policy The address of the policy contract to check.
    /// @param holder The address of the content rights holder to verify authorization.
    function isPolicyAuthorized(address policy, address holder) external view returns (bool);

    /// @notice Authorizes a policy contract, granting it rights to manage the content associated with the holder.
    /// @dev This function allows a content holder to authorize a policy to manage its content rights.
    /// @param policy The address of the policy contract to authorize.
    /// @param data The data to initialize policy.
    function authorizePolicy(address policy, bytes calldata data) external;

    /// @notice Revokes the authorization of a policy contract.
    /// @dev This function removes the rights of a policy, preventing it from managing the content holder’s assets.
    /// @param policy The address of the policy contract to revoke authorization.
    function revokePolicy(address policy) external;
}
