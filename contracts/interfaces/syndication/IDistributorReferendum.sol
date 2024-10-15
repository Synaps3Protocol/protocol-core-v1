// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IDistributorRegistrable } from "contracts/interfaces/syndication/IDistributorRegistrable.sol";
import { IDistributorVerifiable } from "contracts/interfaces/syndication/IDistributorVerifiable.sol";
import { ITreasurer } from "contracts/interfaces/economics/ITreasurer.sol";

/// @title IDistributorReferendum
/// @notice Interface that defines the necessary operations for managing distributor registration, verification, and treasury interactions within a governance framework.
/// @dev This interface combines multiple functionalities, such as registering distributors, verifying their status, and managing treasury-related operations
///      related to distributor enrollments and fees.
interface IDistributorReferendum is IDistributorRegistrable, IDistributorVerifiable, ITreasurer {}
