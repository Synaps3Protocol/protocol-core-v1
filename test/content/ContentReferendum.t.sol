// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IContentRegistrable } from "contracts/interfaces/content/IContentRegistrable.sol";
import { IContentVerifiable } from "contracts/interfaces/content/IContentVerifiable.sol";
import { INonceVerifiable } from "contracts/interfaces/INonceVerifiable.sol";
import { ContentReferendum } from "contracts/content/ContentReferendum.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/libraries/Types.sol";
import { C } from "contracts/libraries/Constants.sol";

contract ContentReferendumTest is BaseTest {
    address referendum;

    function setUp() public {
        // setup the access manager to use during tests..
        deployAndSetAccessManager();
        referendum = deployContentReferendum();
    }

    // TODO move to access manager
    // function test_GrantVerifiedRole_ValidVerifiedRoleGrant() public {
    //     vm.prank(governor);
    //     IContentRoleManager(referendum).grantVerifiedRole(user);
    //     assertTrue(IAccessControl(referendum).hasRole(C.VERIFIED_ROLE, user));
    // }

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

    function test_Submit_SubmittedEventEmmitted() public {
        vm.warp(1641070800);
        vm.prank(user);
        vm.expectEmit(true, false, false, true, address(referendum));
        emit ContentReferendum.Submitted(user, 1641070800, 1);
        IContentRegistrable(referendum).submit(1);
    }


    function test_Submit_SubmittedValidStates() public {
        _submitContentAsUser(1);
        assertFalse(IContentVerifiable(referendum).isActive(1));
        assertFalse(IContentVerifiable(referendum).isApproved(user, 1));
    }

    function test_Approve_ApprovedEventEmitted() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.prank(governor); // approve by governance..
        vm.expectEmit(false, false, false, true, address(referendum));
        emit ContentReferendum.Approved(contentId, 1641070805);
        IContentRegistrable(referendum).approve(contentId);
    }

    function test_Approve_ApprovedValidStates() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);

        vm.prank(governor); // approve by governance..
        IContentRegistrable(referendum).approve(contentId);
        assertTrue(IContentVerifiable(referendum).isActive(contentId));
        assertTrue(IContentVerifiable(referendum).isApproved(user, contentId));
    }

    function test_Reject_RejectedEventEmitted() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.prank(governor); // approve by governance..
        vm.expectEmit(false, false, false, true, address(referendum));
        emit ContentReferendum.Rejected(contentId, 1641070805);
        IContentRegistrable(referendum).reject(contentId);
    }

    function test_Reject_RejectedValidStates() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);

        vm.prank(governor); // approve by governance..
        IContentRegistrable(referendum).reject(contentId);
        assertFalse(IContentVerifiable(referendum).isActive(contentId));
        assertFalse(IContentVerifiable(referendum).isApproved(user, contentId));
    }

    function test_Revoked_RevokedEventEmitted() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        // first an approval should ve done
        // then a revoke should ve done
        IContentRegistrable(referendum).approve(contentId);

        vm.expectEmit(false, false, false, true, address(referendum));
        emit ContentReferendum.Revoked(contentId, 1641070805);
        IContentRegistrable(referendum).revoke(contentId);
        vm.stopPrank(); // reject by governance..

    }

    function test_Revoked_RevokedValidStates() public {
        uint256 contentId = 1;
        _submitAndApproveContent(contentId);
        vm.prank(governor); // approve by governance..
        IContentRegistrable(referendum).revoke(contentId);
        assertFalse(IContentVerifiable(referendum).isActive(contentId));
        assertFalse(IContentVerifiable(referendum).isApproved(user, contentId));
    }

    function _submitAndApproveContent(uint256 contentId) internal {
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        IContentRegistrable(referendum).approve(contentId);
        vm.stopPrank(); // approve by governance..
    }

    function _submitContentAsUser(uint256 contentId) internal {
        vm.prank(user); // the default user submitting content..
        IContentRegistrable(referendum).submit(contentId);
    }
}
