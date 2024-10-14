// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IPolicyAuditorVerifiable
/// @notice Interface that defines the methods required to verify if a policy has been audited.
/// @dev This interface can be implemented by any contract that aims to provide audit verification for policies.
interface IPolicyAuditorVerifiable {
    /// @notice Checks if a specific policy contract has been audited.
    /// @param policy The address of the policy contract to verify.
    /// @return bool Returns true if the policy has been audited, false otherwise.
    function isAudited(address policy) external view returns (bool);
}
