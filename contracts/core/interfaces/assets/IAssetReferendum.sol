// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IAssetRegistrable } from "@synaps3/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "@synaps3/core/interfaces/assets/IAssetVerifiable.sol";

/// @title IAssetReferendum
/// @notice Unified interface for managing content registration and verifications within a referendum-based system.
/// @dev This interface extends both IAssetRegistrable and IAssetVerifiable to provide a single entry point for
///      handling asset registration and verification processes.
interface IAssetReferendum is IAssetRegistrable, IAssetVerifiable {}
