// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IDistributorExpirable } from "contracts/core/interfaces/syndication/IDistributorExpirable.sol";
import { IDistributorRegistrable } from "contracts/core/interfaces/syndication/IDistributorRegistrable.sol";
import { IDistributorVerifiable } from "contracts/core/interfaces/syndication/IDistributorVerifiable.sol";

/// @title IDistributorReferendum
/// @notice Interface that defines the necessary operations for managing distributor registration.
interface IDistributorReferendum is IDistributorRegistrable, IDistributorVerifiable, IDistributorExpirable {}
