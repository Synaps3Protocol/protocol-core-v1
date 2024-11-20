// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IAssetRegistrable } from "@synaps3/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "@synaps3/core/interfaces/assets/IAssetVerifiable.sol";

/// @title IAssetReferendum
/// @notice Interface manage content registration, roles, and verifications within a referendum context.
interface IAssetReferendum is IAssetRegistrable, IAssetVerifiable {}
