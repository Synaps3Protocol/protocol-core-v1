// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetRegistrable } from "contracts/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "contracts/core/interfaces/assets/IAssetVerifiable.sol";
import { INonceVerifiable } from "contracts/core/interfaces/base/INonceVerifiable.sol";
import { AssetVault } from "contracts/assets/AssetVault.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract AssetVaultTest is BaseTest {
    address vault;

    function setUp() public initialize  {
        // setup the access manager to use during tests..
        vault = deployAssetVault();
    }

    function test_SetContent_ExpectedOwner() public {
        vm.warp(1641070800);
        vm.prank(user);
        
    }

    function test_SetContent_RevertIf_InvalidOwner() public {
        vm.warp(1641070800);
        vm.prank(user);
        
    }

    function test_SetContent_ValidVaultType() public {
        vm.warp(1641070800);
        vm.prank(user);
        
    }

    function test_Get_ValidStoredContent() public {
        vm.warp(1641070800);
        vm.prank(user);
        
    }
    
}
