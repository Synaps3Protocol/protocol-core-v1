// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IRightsPolicyManagerVerifiable } from "@synaps3/core/interfaces/rights/IRightsPolicyManagerVerifiable.sol";
import { IRightsPolicyManagerRegistrable } from "@synaps3/core/interfaces/rights/IRightsPolicyManagerRegistrable.sol";

/// @title IRightsPolicyManager
/// @notice Unified interface for verifying, retrieving, and registering content rights policies.
/// @dev This interface extends both `IRightsPolicyManagerVerifiable`
///      (which enables querying and verifying policy assignments) and
///     `IRightsPolicyManagerRegistrable` (which handles registration of new policies).
interface IRightsPolicyManager is IRightsPolicyManagerVerifiable, IRightsPolicyManagerRegistrable {}
