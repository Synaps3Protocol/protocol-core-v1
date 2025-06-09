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

contract AssetReferendumTest is BaseTest {
    function setUp() public initialize {
        // setup the access manager to use during tests..
        deployAssetReferendum();
    }

    function test_Submit_SubmittedEventEmitted() public {
        vm.warp(1641070800);
        vm.prank(user);
        vm.expectEmit(true, true, false, true, address(assetReferendum));
        emit AssetReferendum.Submitted(user, 1);
        IAssetRegistrable(assetReferendum).submit(1);
    }

    function test_Submit_SubmittedValidStates() public {
        _submitContentAsUser(1);
        assertFalse(IAssetVerifiable(assetReferendum).isActive(1), "Asset should not be active yet");
        assertFalse(IAssetVerifiable(assetReferendum).isApproved(user, 1), "Asset should not be approved yet");
    }

    function test_Approve_ApprovedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        vm.expectEmit(true, false, false, true, address(assetReferendum));
        emit AssetReferendum.Approved(assetId);
        IAssetRegistrable(assetReferendum).approve(assetId);
        vm.stopPrank();
    }

    function test_Approve_ApprovedValidStates() public {
        uint256 assetId;
        _submitContentAsUser(assetId);

        vm.prank(governor); // approve by governance..
        IAssetRegistrable(assetReferendum).approve(assetId);
        assertTrue(IAssetVerifiable(assetReferendum).isActive(assetId), "Asset should be active");
        assertTrue(IAssetVerifiable(assetReferendum).isApproved(user, assetId), "Asset should be approved");
    }

    function test_Reject_RejectedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.prank(governor); // approve by governance..
        vm.expectEmit(true, false, false, true, address(assetReferendum));
        emit AssetReferendum.Rejected(assetId);
        IAssetRevokable(assetReferendum).reject(assetId);
    }

    function test_Reject_RejectedValidStates() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);

        vm.prank(governor); // approve by governance..
        IAssetRevokable(assetReferendum).reject(assetId);
        assertFalse(IAssetVerifiable(assetReferendum).isActive(assetId), "Asset should not be active");
        assertFalse(IAssetVerifiable(assetReferendum).isApproved(user, assetId), "Asset should not be approved");
    }

    function test_Revoked_RevokedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        // first an approval should ve done
        // then a revoke should ve done
        IAssetRegistrable(assetReferendum).approve(assetId);

        vm.expectEmit(true, false, false, true, address(assetReferendum));
        emit AssetReferendum.Revoked(assetId);
        IAssetRevokable(assetReferendum).revoke(assetId);
        vm.stopPrank(); // reject by governance..
    }

    function test_Revoked_RevokedValidStates() public {
        uint256 assetId = 1;
        _submitAndApproveContent(assetId);
        vm.prank(governor); // approve by governance..
        IAssetRevokable(assetReferendum).revoke(assetId);
        assertFalse(IAssetVerifiable(assetReferendum).isActive(assetId), "Asset should not be active");
        assertFalse(IAssetVerifiable(assetReferendum).isApproved(user, assetId), "Asset should not be approved");
    }

    function _submitAndApproveContent(uint256 assetId) internal {
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.startPrank(governor); // approve by governance..
        IAssetRegistrable(assetReferendum).approve(assetId);
        vm.stopPrank(); // approve by governance..
    }

    function _submitContentAsUser(uint256 assetId) internal {
        vm.prank(user); // the default user submitting content..
        IAssetRegistrable(assetReferendum).submit(assetId);
    }
}
