// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IQuorumRevokable
/// @notice FSM interface for revoking approved entities.
interface IQuorumRevokable {
    /// @notice Revokes a previously approved entity.
    /// @param entry The ID of the entity.
    function revoke(uint256 entry) external;
}
