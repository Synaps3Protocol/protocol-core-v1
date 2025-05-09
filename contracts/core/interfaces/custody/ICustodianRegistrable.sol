// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title ICustodianRegistrable
/// @dev Interface for managing custodians registration.
/// @dev This interface indirectly implements the FSM defined in `IQuorum` using `QuorumUpgradeable`.
///      Functions here are semantically equivalent to the FSM transitions: register → approve.
interface ICustodianRegistrable {
    /// @notice Registers data with a given identifier.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param currency The currency used to pay enrollment.
    function register(uint256 proof, address currency) external;

    /// @notice Approves the data associated with the given identifier.
    /// @param custodian The address of the custodian to approve.
    function approve(address custodian) external;
}
