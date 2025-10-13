// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IPolicyAuditorVerifiable
/// @notice Interface that defines the methods required to verify if a policy has been audited.
/// @dev This interface can be implemented by any contract that aims to provide audit verification for policies.
interface IPolicyAuditorVerifiable {
    /// @notice Checks if a specific policy has been approved and remains active.
    /// @param policy The address of the policy contract to verify.
    function isApproved(address policy) external view returns (bool);

    /// @notice Checks if a specific policy has been rejected or blocked by the auditor.
    /// @param policy The address of the policy contract to verify.
    function isRejected(address policy) external view returns (bool);

    /// @notice Checks if a specific policy is awaiting approval.
    /// @param policy The address of the policy contract to verify.
    function isPending(address policy) external view returns (bool);
}
