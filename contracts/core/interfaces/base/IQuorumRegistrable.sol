// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IQuorumRegistrable
/// @notice FSM interface for entities that go through registration and decision (approve/reject).
interface IQuorumRegistrable {
    /// @notice Initiates the registration of an entity.
    /// @param entry The generic ID (could be uint160(address) or asset ID).
    function register(uint256 entry) external;

    /// @notice Approves an entity.
    /// @param entry The ID of the entity.
    function approve(uint256 entry) external;

    /// @notice Blocks or rejects an entity before approval.
    /// @param entry The ID of the entity.
    function reject(uint256 entry) external;

    /// @notice Internal function for an entity to resign.
    /// @param entry The ID of the entity.
    function quit(uint256 entry) external;
}
