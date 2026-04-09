// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title ICustodianRegistrable
/// @dev Interface for managing custodians registration.
/// @dev This interface indirectly implements the FSM defined in `IQuorum` using `QuorumUpgradeable`.
///      Functions here are semantically equivalent to the FSM transitions: register → approve.
interface ICustodianRegistrable {
    /// @notice Registers a custodian to be approved by council.
    /// @param custodian The address of the custodian to register.
    function register(address custodian) external;

    /// @notice Approves the data custodian with the given address.
    /// @param custodian The address of the custodian to approve.
    function approve(address custodian) external;
}
