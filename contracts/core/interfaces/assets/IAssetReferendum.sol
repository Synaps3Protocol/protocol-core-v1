// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IAssetReferendumRegistrable } from "@synaps3/core/interfaces/assets/IAssetReferendumRegistrable.sol";
import { IAssetReferendumVerifiable } from "@synaps3/core/interfaces/assets/IAssetReferendumVerifiable.sol";
import { IAssetReferendumRevokable } from "@synaps3/core/interfaces/assets/IAssetReferendumRevokable.sol";

/// @title IAssetReferendum
/// @notice Unified interface for managing content registration and verifications within a referendum-based system.
/// @dev This interface extends both IAssetReferendumRegistrable and IAssetReferendumVerifiable to provide a single entry point for
///      handling asset registration and verification processes.
interface IAssetReferendum is IAssetReferendumRegistrable, IAssetReferendumVerifiable, IAssetReferendumRevokable {}
