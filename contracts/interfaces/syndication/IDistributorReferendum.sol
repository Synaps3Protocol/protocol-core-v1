// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IDistributorRegistrable } from "contracts/interfaces/syndication/IDistributorRegistrable.sol";
import { IDistributorVerifiable } from "contracts/interfaces/syndication/IDistributorVerifiable.sol";
import { IDistributor } from "contracts/interfaces/syndication/IDistributor.sol";
import { ITreasurer } from "contracts/interfaces/economics/ITreasurer.sol";

interface IDistributorReferendum is IDistributorRegistrable, IDistributorVerifiable, ITreasurer {}
