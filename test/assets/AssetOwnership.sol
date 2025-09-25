// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetRegistrable } from "contracts/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetRevokable } from "contracts/core/interfaces/assets/IAssetRevokable.sol";
import { IAssetVerifiable } from "contracts/core/interfaces/assets/IAssetVerifiable.sol";
import { AssetReferendum } from "contracts/assets/AssetReferendum.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract AssetOwnershipTest is BaseTest {
    function setUp() public initialize {
        // setup the access manager to use during tests..
        deployAssetOwnership();
    }



    

    
}
