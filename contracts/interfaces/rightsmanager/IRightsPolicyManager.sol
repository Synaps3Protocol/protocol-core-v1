// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ITreasurer } from "contracts/interfaces/economics/ITreasurer.sol";
import { IBalanceWithdrawable } from "contracts/interfaces/IBalanceWithdrawable.sol";

/// @title IRightsPolicyManager
/// @notice Interface for controlling access and managing policies related to content rights in the RightsManager context.
/// @dev This interface handles retrieving active policies, managing lists of policies, and registering policies.
interface IRightsPolicyManager is IBalanceWithdrawable, ITreasurer {
    /// @notice Retrieves the first active policy for a specific account, rights holder, and content in LIFO order.
    /// @param account The address of the account to evaluate.
    /// @param contentId The ID of the content to evaluate policies for.
    /// @return A boolean indicating if a policy is active, and the address of the active policy.
    function getActivePolicy(address account, uint256 contentId) external returns (bool, address);

    /// @notice Retrieves the list of policies associated with a specific account and content ID.
    /// @param account The address of the account for which policies are being retrieved.
    /// @return An array of addresses representing the policies associated with the account and content ID.
    function getPolicies(address account) external view returns (address[] memory);

    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param policyAddress The address of the policy contract managing the agreement.
    function registerPolicy(bytes32 proof, address policyAddress) external payable;
}
