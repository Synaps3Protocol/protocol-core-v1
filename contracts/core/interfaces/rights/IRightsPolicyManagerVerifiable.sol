// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsPolicyManagerVerifiable
/// @notice Interface for verifying and retrieving information about content rights policies registration.
/// @dev This interface provides verification functions to check policy assignments and active status.
interface IRightsPolicyManagerVerifiable {
    /// @notice Retrieves the list of policies associated with a specific account.
    /// @dev Returns all policies linked to the given account.
    /// @param account The address of the account for which policies are being retrieved.
    /// @return An array of addresses representing the associated policies.
    function getPolicies(address account) external view returns (address[] memory);

    /// @notice Retrieves the first active policy matching the criteria for an account in LIFO order.
    /// @dev This function searches for a policy that satisfies the provided criteria, returning the most recent match.
    /// @param account Address of the account to evaluate.
    /// @param criteria Encoded data containing parameters for access verification.
    /// @return active True if a policy matches; otherwise, false.
    /// @return policyAddress Address of the matching policy or zero if none found.
    function getActivePolicy(address account, bytes memory criteria) external view returns (bool, address);

    /// @notice Retrieves the list of active policies matching the criteria for an account.
    /// @dev Returns all active policies that match the given criteria.
    /// @param account Address of the account to evaluate.
    /// @param criteria Encoded data containing parameters for access verification (e.g., assetId, holder).
    /// @return An array of addresses representing the active policies.
    function getActivePolicies(address account, bytes memory criteria) external view returns (address[] memory);

    /// @notice Verifies if a specific policy is active for the provided account and content.
    /// @dev Checks whether the policy contract meets the given criteria for the user's access rights.
    /// @param account The address of the user whose compliance is being evaluated.
    /// @param policy The address of the policy contract to check compliance against.
    /// @param criteria Encoded data containing the parameters required to verify access.
    /// @return True if the policy is active and valid, false otherwise.
    function isActivePolicy(address account, address policy, bytes calldata criteria) external view returns (bool);
}
