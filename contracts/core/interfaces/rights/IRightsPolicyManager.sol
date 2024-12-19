// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsPolicyManager
/// @notice Interface for managing content rights policies.
/// @dev This interface handles retrieving/managing/registering policies.
interface IRightsPolicyManager {
    /// @notice Retrieves the list of policies associated with a specific account and content ID.
    /// @param account The address of the account for which policies are being retrieved.
    function getPolicies(address account) external view returns (address[] memory);

    /// @notice Retrieves the address of the Rights Policies Authorizer contract.
    /// @return The address of the contract responsible for authorizing rights policies.
    function getPolicyAuthorizer() external view returns (address);

    /// @notice Verifies if a specific policy is active for the provided account and content.
    /// @param account The address of the user whose compliance is being evaluated.
    /// @param criteria Encoded data containing the parameters required to verify access.
    /// @param policyAddress The address of the policy contract to check compliance against.
    function isActivePolicy(
        address account,
        bytes calldata criteria,
        address policyAddress
    ) external view returns (bool);

    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param holder The rights holder whose authorization is required for accessing the asset.
    /// @param policyAddress The address of the policy contract managing the agreement.
    function registerPolicy(uint256 proof, address holder, address policyAddress) external returns (uint256[] memory);
}
