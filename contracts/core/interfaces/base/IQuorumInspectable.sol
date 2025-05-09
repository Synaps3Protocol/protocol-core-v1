// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

/// @title IQuorumInspectable
/// @notice Interface for querying the status of registered entities.
interface IQuorumInspectable {
    /// @notice Returns the current FSM status of the entity.
    function status(uint256 entry) external view returns (T.Status);
}
