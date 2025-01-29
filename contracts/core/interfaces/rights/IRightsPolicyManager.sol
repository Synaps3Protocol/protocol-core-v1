// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IRightsPolicyManagerVerifiable } from "@synaps3/core/interfaces/rights/IRightsPolicyManagerVerifiable.sol";
import { IRightsPolicyManagerRegistrable } from "@synaps3/core/interfaces/rights/IRightsPolicyManagerRegistrable.sol";

/// @title IRightsPolicyManager
/// @notice Unified interface for verifying, retrieving, and registering content rights policies.
/// @dev This interface extends both `IRightsPolicyManagerVerifiable` (which enables querying and verifying policy assignments)
///      and `IRightsPolicyManagerRegistrable` (which handles registration of new policies).
interface IRightsPolicyManager is IRightsPolicyManagerVerifiable, IRightsPolicyManagerRegistrable {

}
