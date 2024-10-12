// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IPolicyAuthorizer
/// @notice Interface for authorizing and managing policies related to content rights.
/// @dev This interface allows content holders to authorize, and revoke policies that manage their rights.
interface IRightsPolicyAuthorizer {

    /// @notice Retrieves all policies to which rights have been authorized by a specific content holder.
    /// @dev This function returns an array of addresses representing the policies authorized by the content holder.
    /// @param holder The content rights holder whose delegated policies are being queried.
    /// @return An array of policy contract addresses that have been delegated rights by the specified content holder.
    function getAuthorizedPolicies(address holder) external view returns (address[] memory);

    /// @notice Checks if a specific policy contract has been authorized by a content holder.
    /// @dev This function verifies if the specified policy has been granted rights by the given holder.
    /// @param policy The address of the policy contract to check for delegation.
    /// @param holder The content rights holder to check for the delegation of rights.
    /// @return bool Returns true if the policy has been authorized by the content holder, otherwise false.
    function isPolicyAuthorized(address policy, address holder) external view returns (bool);

    /// @notice Authorizes a policy contract, granting it the rights to manage content held by the holder.
    /// @dev This function allows a content holder to delegate specific rights to a policy contract.
    /// @param policy The address of the policy contract to be initialized and authorized.
    function authorizePolicy(address policy) external;

    /// @notice Revokes the delegation of rights to a specific policy contract.
    /// @dev This function removes the authorization of a policy, preventing it from managing the content holder’s rights.
    /// @param policy The address of the policy contract whose rights delegation is being revoked.
    function revokePolicy(address policy) external;
}
