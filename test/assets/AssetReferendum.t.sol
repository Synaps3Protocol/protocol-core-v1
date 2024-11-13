// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetRegistrable } from "contracts/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "contracts/interfaces/assets/IAssetVerifiable.sol";
import { INonceVerifiable } from "contracts/interfaces/INonceVerifiable.sol";
import { AssetReferendum } from "contracts/assets/AssetReferendum.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/libraries/Types.sol";
import { C } from "contracts/libraries/Constants.sol";

contract AssetReferendumTest is BaseTest {
    address referendum;

    function setUp() public initialize  {
        // setup the access manager to use during tests..
        referendum = deployAssetReferendum();
    }

    function test_Submit_SubmittedEventEmmitted() public {
        vm.warp(1641070800);
        vm.prank(user);
        vm.expectEmit(true, false, false, true, address(referendum));
        emit AssetReferendum.Submitted(user, 1641070800, 1);
        IAssetRegistrable(referendum).submit(1);
    }

    function test_Submit_SubmittedValidStates() public {
        _submitContentAsUser(1);
        assertFalse(IAssetVerifiable(referendum).isActive(1));
        assertFalse(IAssetVerifiable(referendum).isApproved(user, 1));
    }

    function test_Approve_ApprovedEventEmitted() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.prank(governor); // approve by governance..
        vm.expectEmit(false, false, false, true, address(referendum));
        emit AssetReferendum.Approved(contentId, 1641070805);
        IAssetRegistrable(referendum).approve(contentId);
    }

    function test_Approve_ApprovedValidStates() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);

        vm.prank(governor); // approve by governance..
        IAssetRegistrable(referendum).approve(contentId);
        assertTrue(IAssetVerifiable(referendum).isActive(contentId));
        assertTrue(IAssetVerifiable(referendum).isApproved(user, contentId));
    }

    function test_Reject_RejectedEventEmitted() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.prank(governor); // approve by governance..
        vm.expectEmit(false, false, false, true, address(referendum));
        emit AssetReferendum.Rejected(contentId, 1641070805);
        IAssetRegistrable(referendum).reject(contentId);
    }

    function test_Reject_RejectedValidStates() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);

        vm.prank(governor); // approve by governance..
        IAssetRegistrable(referendum).reject(contentId);
        assertFalse(IAssetVerifiable(referendum).isActive(contentId));
        assertFalse(IAssetVerifiable(referendum).isApproved(user, contentId));
    }

    function test_Revoked_RevokedEventEmitted() public {
        uint256 contentId = 1;
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        // first an approval should ve done
        // then a revoke should ve done
        IAssetRegistrable(referendum).approve(contentId);

        vm.expectEmit(false, false, false, true, address(referendum));
        emit AssetReferendum.Revoked(contentId, 1641070805);
        IAssetRegistrable(referendum).revoke(contentId);
        vm.stopPrank(); // reject by governance..

    }

    function test_Revoked_RevokedValidStates() public {
        uint256 contentId = 1;
        _submitAndApproveContent(contentId);
        vm.prank(governor); // approve by governance..
        IAssetRegistrable(referendum).revoke(contentId);
        assertFalse(IAssetVerifiable(referendum).isActive(contentId));
        assertFalse(IAssetVerifiable(referendum).isApproved(user, contentId));
    }

    function _submitAndApproveContent(uint256 contentId) internal {
        _submitContentAsUser(contentId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        IAssetRegistrable(referendum).approve(contentId);
        vm.stopPrank(); // approve by governance..
    }

    function _submitContentAsUser(uint256 contentId) internal {
        vm.prank(user); // the default user submitting content..
        IAssetRegistrable(referendum).submit(contentId);
    }
}
