// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IRightsAssetCustodianManager } from "@synaps3/core/interfaces/rights/IRightsAssetCustodianManager.sol";
import { IRightsAssetCustodianVerifiable } from "@synaps3/core/interfaces/rights/IRightsAssetCustodianVerifiable.sol";
import { IRightsAssetCustodianRegistrable } from "@synaps3/core/interfaces/rights/IRightsAssetCustodianRegistrable.sol";

/// @title IRightsAssetCustodian
/// @notice Unified interface for verifying, retrieving, and managing custodial rights over assets.
/// @dev This interface extends both `IRightsAssetCustodianVerifiable` (which enables querying custodianship status)
///      and `IRightsAssetCustodianRegistrable` (which handles granting and revoking custodial rights).
interface IRightsAssetCustodian is
    IRightsAssetCustodianManager,
    IRightsAssetCustodianRegistrable,
    IRightsAssetCustodianVerifiable
{}
