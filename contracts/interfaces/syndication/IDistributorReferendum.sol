// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IDistributorExpirable } from "contracts/interfaces/syndication/IDistributorExpirable.sol";
import { IDistributorRegistrable } from "contracts/interfaces/syndication/IDistributorRegistrable.sol";
import { IDistributorVerifiable } from "contracts/interfaces/syndication/IDistributorVerifiable.sol";
import { ITreasurer } from "contracts/interfaces/economics/ITreasurer.sol";

/// @title IDistributorReferendum
/// @notice Interface that defines the necessary operations for managing distributor registration.
interface IDistributorReferendum is
    IDistributorRegistrable,
    IDistributorVerifiable,
    IDistributorExpirable,
    ITreasurer
{}
