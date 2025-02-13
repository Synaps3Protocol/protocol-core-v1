// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IRightsPolicyAuthorizerVerifiable
/// @notice Interface for verifying and retrieving information about authorized content rights policies.
/// @dev This interface provides read-access functions to check which policies have been authorized by a content holder
///      and whether a specific policy is permitted to manage a holder's rights.
interface IRightsPolicyAuthorizerVerifiable {
    /// @notice Retrieves all policies that have been authorized by a specific content holder.
    /// @param holder The address of the content rights holder whose authorized policies are being queried.
    /// @return An array of policy contract addresses that have been authorized by the holder.
    function getAuthorizedPolicies(address holder) external view returns (address[] memory);

    /// @notice Checks whether a specific policy contract has been authorized by a content holder.
    /// @param policy The address of the policy contract to check.
    /// @param holder The address of the content rights holder whose authorization is being verified.
    /// @return A boolean value indicating whether the policy is authorized (`true`) or not (`false`).
    function isPolicyAuthorized(address policy, address holder) external view returns (bool);
}
