// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IContentRegistrable } from "contracts/interfaces/assets/IContentRegistrable.sol";
import { IContentRoleManager } from "contracts/interfaces/assets/IContentRoleManager.sol";
import { IContentVerifiable } from "contracts/interfaces/assets/IContentVerifiable.sol";

/// @title IContentReferendum
/// @notice Interface that combines functionalities for managing content registration, roles, and verifications within a referendum context.
/// @dev This interface inherits from multiple content-related interfaces, enabling content registration, role management, and verification in governance-based decisions.
interface IContentReferendum is IContentRegistrable, IContentRoleManager, IContentVerifiable {}
