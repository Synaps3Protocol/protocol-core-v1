// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { IContentRegistrable } from "contracts/interfaces/content/IContentRegistrable.sol";
import { IContentVerifiable } from "contracts/interfaces/content/IContentVerifiable.sol";
import { INonceVerifiable } from "contracts/interfaces/INonceVerifiable.sol";
import { ContentReferendum } from "contracts/content/ContentReferendum.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/libraries/Types.sol";
import { C } from "contracts/libraries/Constants.sol";

contract AccessManagerTest is BaseTest {
    function setUp() BroadcastedByAdmin public {
        // setup the access manager to use during tests..
        accessManager = deployAndSetAccessManager();
    }

    function test_GrantVerifiedRole_ValidVerifiedRoleGrant() public {
        vm.prank(governor);
        IAccessManager(accessManager).grantRole(C.VERIFIED_ROLE, user);
        assertTrue(IAccessManager(accessManager).hasRole(C.VERIFIED_ROLE, user));
    }

    // function test_GrantVerifiedRole_RevertWhen_Unauthorized() public {
    //     vm.expectRevert();
    //     IContentRoleManager(referendum).grantVerifiedRole(user);
    // }

    // function test_RevokeVerifiedRole_ValidVerifiedRoleRevoke() public {
    //     vm.prank(governor);
    //     IContentRoleManager(referendum).revokeVerifiedRole(user);
    //     assertFalse(IAccessControl(referendum).hasRole(C.VERIFIED_ROLE, user));
    // }

    // function test_RevokeVerifiedRole_RevertWhen_Unauthorized() public {
    //     vm.expectRevert();
    //     IContentRoleManager(referendum).revokeVerifiedRole(user);
    // }

    
}
