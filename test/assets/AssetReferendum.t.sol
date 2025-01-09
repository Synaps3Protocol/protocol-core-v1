// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetRegistrable } from "contracts/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "contracts/core/interfaces/assets/IAssetVerifiable.sol";
import { AssetReferendum } from "contracts/assets/AssetReferendum.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract AssetReferendumTest is BaseTest {
    address referendum;

    function setUp() public initialize {
        // setup the access manager to use during tests..
        referendum = deployAssetReferendum();
    }

    function test_Submit_SubmittedEventEmitted() public {
        vm.warp(1641070800);
        vm.prank(user);
        vm.expectEmit(true, false, false, true, address(referendum));
        emit AssetReferendum.Submitted(user, 1);
        IAssetRegistrable(referendum).submit(1);
    }

    function test_Submit_SubmittedValidStates() public {
        _submitContentAsUser(1);
        assertFalse(IAssetVerifiable(referendum).isActive(1));
        assertFalse(IAssetVerifiable(referendum).isApproved(user, 1));
    }

    function test_Approve_ApprovedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        vm.expectEmit(false, false, false, true, address(referendum));
        emit AssetReferendum.Approved(assetId);
        IAssetRegistrable(referendum).approve(assetId);
        vm.stopPrank();
    }

    function test_Approve_ApprovedValidStates() public {
        uint256 assetId;
        _submitContentAsUser(assetId);

        vm.prank(governor); // approve by governance..
        IAssetRegistrable(referendum).approve(assetId);
        assertTrue(IAssetVerifiable(referendum).isActive(assetId));
        assertTrue(IAssetVerifiable(referendum).isApproved(user, assetId));
    }

    function test_Reject_RejectedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.prank(governor); // approve by governance..
        vm.expectEmit(false, false, false, true, address(referendum));
        emit AssetReferendum.Rejected(assetId);
        IAssetRegistrable(referendum).reject(assetId);
    }

    function test_Reject_RejectedValidStates() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);

        vm.prank(governor); // approve by governance..
        IAssetRegistrable(referendum).reject(assetId);
        assertFalse(IAssetVerifiable(referendum).isActive(assetId));
        assertFalse(IAssetVerifiable(referendum).isApproved(user, assetId));
    }

    function test_Revoked_RevokedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        // first an approval should ve done
        // then a revoke should ve done
        IAssetRegistrable(referendum).approve(assetId);

        vm.expectEmit(false, false, false, true, address(referendum));
        emit AssetReferendum.Revoked(assetId);
        IAssetRegistrable(referendum).revoke(assetId);
        vm.stopPrank(); // reject by governance..
    }

    function test_Revoked_RevokedValidStates() public {
        uint256 assetId = 1;
        _submitAndApproveContent(assetId);
        vm.prank(governor); // approve by governance..
        IAssetRegistrable(referendum).revoke(assetId);
        assertFalse(IAssetVerifiable(referendum).isActive(assetId));
        assertFalse(IAssetVerifiable(referendum).isApproved(user, assetId));
    }

    function _submitAndApproveContent(uint256 assetId) internal {
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        IAssetRegistrable(referendum).approve(assetId);
        vm.stopPrank(); // approve by governance..
    }

    function _submitContentAsUser(uint256 assetId) internal {
        vm.prank(user); // the default user submitting content..
        IAssetRegistrable(referendum).submit(assetId);
    }
}
