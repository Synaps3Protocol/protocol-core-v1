// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IPolicyAuditorRegistrable
/// @notice Interface for auditing and revoking audits for policy controllers.
/// @dev This interface allows external contracts to approve or revoke the audit status of a specific policy.
interface IPolicyAuditorRegistrable {
    /// @notice Submits an audit request for the given policy.
    /// This registers the policy for audit within the system.
    /// @param policy The address of the policy to be submitted for auditing.
    function submit(address policy) external;

    /// @notice Approves the audit of a given policy by a specified auditor.
    /// @param policy The address of the policy to be audited.
    function approve(address policy) external;

    /// @notice Revokes the audit of a given policy by a specified auditor.
    /// @param policy The address of the policy whose audit is to be revoked.
    function reject(address policy) external;
}
