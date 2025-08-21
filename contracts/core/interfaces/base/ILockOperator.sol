// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ILockClaimer } from "@synaps3/core/interfaces/base/ILockClaimer.sol";
import { ILockReleaser } from "@synaps3/core/interfaces/base/ILockReleaser.sol";
import { ILockLocker } from "@synaps3/core/interfaces/base/ILockLocker.sol";

/// @title ILockOperator
/// @notice Unified interface that composes locker, releaser, and claimer capabilities.
/// @dev Adds a common read method to query the locked balance.
interface ILockOperator is ILockClaimer, ILockLocker, ILockReleaser {

}
