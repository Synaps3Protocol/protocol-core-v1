// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IAssetRegistrable } from "@synaps3/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "@synaps3/core/interfaces/assets/IAssetVerifiable.sol";
import { IAssetRevokable } from "@synaps3/core/interfaces/assets/IAssetRevokable.sol";

/// @title IAssetReferendum
/// @notice Unified interface for managing content registration and verifications within a referendum-based system.
/// @dev This interface extends both IAssetRegistrable and IAssetVerifiable to provide a single entry point for
///      handling asset registration and verification processes.
interface IAssetReferendum is IAssetRegistrable, IAssetVerifiable, IAssetRevokable {}
