// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ITreasurer } from "contracts/interfaces/economics/ITreasurer.sol";
import { IBalanceWithdrawable } from "contracts/interfaces/IBalanceWithdrawable.sol";

/// @title IRightsPolicyManager
/// @notice Interface for managing content rights policies.
/// @dev This interface handles retrieving active compliant policy, managing lists of policies, and registering policies.
interface IRightsPolicyManager is IBalanceWithdrawable, ITreasurer {
    /// @notice Verifies if a specific policy is compliant for the provided account and criteria.
    /// @param account The address of the user whose compliance is being evaluated.
    /// @param policyAddress The address of the policy contract to check compliance against.
    function isCompliantPolicy(address account, address policyAddress) external view returns (bool);

    /// @notice Verifies if a specific policy is compliant for the provided account and criteria.
    /// @param account The address of the user whose compliance is being evaluated.
    /// @param contentId The identifier of the content to validate the policy status.
    /// @param policyAddress The address of the policy contract to check compliance against.
    function isActivePolicy(address account, uint256 contentId, address policyAddress) external view returns (bool);

    /// @notice Retrieves the first active policy for a specific account in LIFO order.
    /// @param account The address of the account to evaluate.
    /// @param contentId The identifier of the content to validate the policy status.
    function getActivePolicy(address account, uint256 contentId) external view returns (bool, address);

    /// @notice Retrieves the list of policies associated with a specific account and content ID.
    /// @param account The address of the account for which policies are being retrieved.
    function getPolicies(address account) external view returns (address[] memory);

    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param policyAddress The address of the policy contract managing the agreement.
    function registerPolicy(bytes32 proof, address policyAddress) external payable returns (uint256);
}
