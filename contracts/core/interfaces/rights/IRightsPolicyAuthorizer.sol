// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
// solhint-disable-next-line max-line-length
import { IRightsPolicyAuthorizerRegistrable } from "@synaps3/core/interfaces/rights/IRightsPolicyAuthorizerRegistrable.sol";
// solhint-disable-next-line max-line-length
import { IRightsPolicyAuthorizerVerifiable } from "@synaps3/core/interfaces/rights/IRightsPolicyAuthorizerVerifiable.sol";

/// @title IRightsPolicyAuthorizer
/// @notice Unified interface for registering, managing, and verifying content rights policies.
/// @dev This interface combines functionalities for policy authorization, revocation, and verification.
///      It extends both `IRightsPolicyAuthorizerRegistrable` (which allows policy registration and revocation)
///      and `IRightsPolicyAuthorizerVerifiable` (which enables querying and verifying policy authorizations).
interface IRightsPolicyAuthorizer is IRightsPolicyAuthorizerVerifiable, IRightsPolicyAuthorizerRegistrable {}
