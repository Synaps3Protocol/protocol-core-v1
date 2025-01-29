// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsPolicyManagerRegistrable
/// @notice Interface for registering and managing content rights policies.
/// @dev This interface provides functions for registering and finalizing policies.
interface IRightsPolicyManagerRegistrable {
    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @dev This function ensures that the policy is properly recorded and recognized in the system.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param holder The rights holder whose authorization is required for accessing the asset.
    /// @param policyAddress The address of the policy contract managing the agreement.
    /// @return An array containing the registered policy identifiers.
    function registerPolicy(uint256 proof, address holder, address policyAddress) external returns (uint256[] memory);
}
