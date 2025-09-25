// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetReferendumRegistrable } from "contracts/core/interfaces/assets/IAssetReferendumRegistrable.sol";
import { IAssetReferendumRevokable } from "contracts/core/interfaces/assets/IAssetReferendumRevokable.sol";
import { IAssetReferendumVerifiable } from "contracts/core/interfaces/assets/IAssetReferendumVerifiable.sol";
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
        IAssetReferendumRegistrable(assetReferendum).submit(1);
    }

    function test_Submit_SubmittedValidStates() public {
        _submitContentAsUser(1);
        IAssetReferendumVerifiable referendum =  IAssetReferendumVerifiable(assetReferendum);
        assertFalse(referendum.isActive(1), "Asset should not be active yet");
        assertFalse(referendum.isApproved(user, 1), "Asset should not be approved yet");
    }

    function test_Approve_ApprovedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.startPrank(contentCouncil); // approve by council..
        vm.expectEmit(true, false, false, true, address(assetReferendum));
        emit AssetReferendum.Approved(assetId);
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);
        vm.stopPrank();
    }

    function test_Approve_ApprovedValidStates() public {
        uint256 assetId = 1;
        
        _submitContentAsUser(assetId);
        
        vm.prank(contentCouncil); // approve by council..
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);
        
        IAssetReferendumVerifiable referendum =  IAssetReferendumVerifiable(assetReferendum);
        assertTrue(referendum.isActive(assetId), "Asset should be active");
        assertTrue(referendum.isApproved(user, assetId), "Asset should be approved");
    }

    function test_Reject_RejectedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.prank(contentCouncil); // approve by council..
        vm.expectEmit(true, false, false, true, address(assetReferendum));
        emit AssetReferendum.Rejected(assetId);

        IAssetReferendumRevokable(assetReferendum).reject(assetId);
    }

    function test_Reject_RejectedValidStates() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);

        vm.prank(contentCouncil); // approve by council..
        IAssetReferendumRevokable(assetReferendum).reject(assetId);
        
        IAssetReferendumVerifiable referendum =  IAssetReferendumVerifiable(assetReferendum);
        assertFalse(referendum.isActive(assetId), "Asset should not be active");
        assertFalse(referendum.isApproved(user, assetId), "Asset should not be approved");
    }

    function test_Revoked_RevokedEventEmitted() public {
        uint256 assetId = 1;
        _submitContentAsUser(assetId);
        vm.warp(1641070805);

        vm.startPrank(contentCouncil); // approve by council..
        // first an approval should ve done
        // then a revoke 
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);

        vm.expectEmit(true, false, false, true, address(assetReferendum));
        emit AssetReferendum.Revoked(assetId);
        IAssetReferendumRevokable(assetReferendum).revoke(assetId);
        vm.stopPrank(); // reject by governance..
    }

    function test_Revoked_RevokedValidStates() public {
        uint256 assetId = 1;
        _submitAndApproveContent(assetId);
        vm.prank(contentCouncil); // approve by council..
        IAssetReferendumRevokable(assetReferendum).revoke(assetId);

        IAssetReferendumVerifiable referendum =  IAssetReferendumVerifiable(assetReferendum);
        assertFalse(referendum.isActive(assetId), "Asset should not be active");
        assertFalse(referendum.isApproved(user, assetId), "Asset should not be approved");
    }

    function _submitAndApproveContent(uint256 assetId) internal {
        _submitContentAsUser(assetId);
        vm.warp(1641070805);
        vm.prank(contentCouncil); // approve by council..
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);
        vm.stopPrank(); // approve by governance..
    }

    function _submitContentAsUser(uint256 assetId) internal {
        vm.prank(user); // the default user submitting content..
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);
    }
}
