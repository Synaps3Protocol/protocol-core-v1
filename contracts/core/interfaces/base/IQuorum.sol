// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IQuorumRegistrable } from "@synaps3/core/interfaces/base/IQuorumRegistrable.sol";
import { IQuorumRevokable } from "@synaps3/core/interfaces/base/IQuorumRevokable.sol";
import { IQuorumInspectable } from "@synaps3/core/interfaces/base/IQuorumInspectable.sol";

/// @title IQuorum
/// @notice Aggregates the full lifecycle of an FSM-driven entity registration system.
/// @dev Combines registration, approval, rejection, revocation, and status inspection.
///      Intended for systems that use `QuorumUpgradeable` as FSM logic layer.
interface IQuorum is
    IQuorumRegistrable,
    IQuorumRevokable,
    IQuorumInspectable
{}
