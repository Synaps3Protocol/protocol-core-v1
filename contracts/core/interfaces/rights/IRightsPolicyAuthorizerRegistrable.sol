// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsPolicyAuthorizerRegistrable
/// @notice Interface for managing the authorization and registration of policies governing content rights.
/// @dev This interface allows content holders to grant and revoke authorization for policies
///      that control the rights associated with their assets. It provides mechanisms to register
///      policies and manage their permissions.
interface IRightsPolicyAuthorizerRegistrable {
    /// @notice Grants authorization to a policy contract, allowing it to enforce rules on the asset holder's content.
    /// @param policy The address of the policy contract to be authorized.
    /// @param data Additional initialization parameters for the policy contract.
    function authorizePolicy(address policy, bytes calldata data) external;

    /// @notice Revokes authorization of a previously authorized policy contract.
    /// @param policy The address of the policy contract whose authorization is being revoked.
    function revokePolicy(address policy) external;
}
