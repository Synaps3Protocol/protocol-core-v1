// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ICustodianRevokable
/// @dev Interface for revoking approved custodians.
interface ICustodianRevokable {
    /// @notice Revokes the active status of a custodian.
    /// @param custodian The address of the custodian to revoke.
    function revoke(address custodian) external;
}
