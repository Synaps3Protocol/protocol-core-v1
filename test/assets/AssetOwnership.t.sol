// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetOwnership } from "contracts/core/interfaces/assets/IAssetOwnership.sol";
import { IAssetReferendumRegistrable } from "contracts/core/interfaces/assets/IAssetReferendumRegistrable.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract AssetOwnershipTest is BaseTest {
    function setUp() public initialize {
        // setup the access manager to use during tests..
        deployAssetOwnership();
    }


    function test_Register_ValidRegistration() public {
        uint256 assetId = 1;
        
        vm.prank(user);
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);
        
        vm.prank(user);
        IAssetOwnership(assetOwnership).register(user, assetId);
        assertEq(IAssetOwnership(assetOwnership).ownerOf(assetId), user, "Invalid unexpected owner");

    }


    
}
