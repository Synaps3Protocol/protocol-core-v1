// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IContentRegistrable } from "contracts/interfaces/content/IContentRegistrable.sol";
import { IContentVerifiable } from "contracts/interfaces/content/IContentVerifiable.sol";

/// @title IContentReferendum
/// @notice Interface manage content registration, roles, and verifications within a referendum context.
interface IContentReferendum is IContentRegistrable, IContentVerifiable {}
