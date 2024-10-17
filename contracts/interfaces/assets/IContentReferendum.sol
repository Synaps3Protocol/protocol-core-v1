// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IContentRegistrable } from "contracts/interfaces/assets/IContentRegistrable.sol";
import { IContentRoleManager } from "contracts/interfaces/assets/IContentRoleManager.sol";
import { IContentVerifiable } from "contracts/interfaces/assets/IContentVerifiable.sol";

/// @title IContentReferendum
/// @notice Interface manage content registration, roles, and verifications within a referendum context.
interface IContentReferendum is IContentRegistrable, IContentRoleManager, IContentVerifiable {}
