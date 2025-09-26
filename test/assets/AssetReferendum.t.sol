// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAssetReferendumRegistrable } from "contracts/core/interfaces/assets/IAssetReferendumRegistrable.sol";
import { IAssetReferendumRevokable } from "contracts/core/interfaces/assets/IAssetReferendumRevokable.sol";
import { IAssetReferendumVerifiable } from "contracts/core/interfaces/assets/IAssetReferendumVerifiable.sol";
import { AssetReferendum } from "contracts/assets/AssetReferendum.sol";

import { BaseTest } from "test/BaseTest.t.sol";

contract AssetReferendumHandler is Test {
    enum Status {
        None,
        Submitted,
        Approved,
        Rejected,
        Revoked
    }

    struct AssetState {
        Status status;
        address submitter;
    }

    address public immutable referendum;
    address public immutable council;

    address[] public actors;

    uint256[] private _trackedAssets;
    mapping(uint256 => AssetState) private _assets;

    constructor(address referendum_, address council_) {
        referendum = referendum_;
        council = council_;

        for (uint256 i = 0; i < 6; i++) {
            actors.push(vm.addr(i + 111));
        }
    }

    function submit(uint256 assetSeed, uint256 actorSeed) external {
        if (actors.length == 0) return;

        uint256 assetId = bound(assetSeed, 1, type(uint128).max);
        AssetState storage state = _assets[assetId];
        if (state.status != Status.None) return;

        address submitter = actors[actorSeed % actors.length];

        vm.prank(submitter);
        IAssetReferendumRegistrable(referendum).submit(assetId);

        state.status = Status.Submitted;
        state.submitter = submitter;
        _trackedAssets.push(assetId);
    }

    function approve(uint256 assetSeed) external {
        if (_trackedAssets.length == 0) return;

        uint256 assetId = _trackedAssets[assetSeed % _trackedAssets.length];
        AssetState storage state = _assets[assetId];
        if (state.status != Status.Submitted) return;

        vm.prank(council);
        IAssetReferendumRegistrable(referendum).approve(assetId);

        state.status = Status.Approved;
    }

    function reject(uint256 assetSeed) external {
        if (_trackedAssets.length == 0) return;

        uint256 assetId = _trackedAssets[assetSeed % _trackedAssets.length];
        AssetState storage state = _assets[assetId];
        if (state.status != Status.Submitted) return;

        vm.prank(council);
        IAssetReferendumRevokable(referendum).reject(assetId);

        state.status = Status.Rejected;
    }

    function revoke(uint256 assetSeed) external {
        if (_trackedAssets.length == 0) return;

        uint256 assetId = _trackedAssets[assetSeed % _trackedAssets.length];
        AssetState storage state = _assets[assetId];
        if (state.status != Status.Approved) return;

        vm.prank(council);
        IAssetReferendumRevokable(referendum).revoke(assetId);

        state.status = Status.Revoked;
    }

    function trackedLength() external view returns (uint256) {
        return _trackedAssets.length;
    }

    function trackedAt(uint256 index) external view returns (uint256) {
        return _trackedAssets[index];
    }

    function stateOf(uint256 assetId) external view returns (AssetState memory) {
        return _assets[assetId];
    }
}

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

    function testFuzz_SubmitAndApprove(address submitter, uint256 assetId) public {
        vm.assume(submitter != address(0));
        vm.assume(submitter != contentCouncil);
        assetId = bound(assetId, 1, type(uint128).max);

        vm.prank(submitter);
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);

        IAssetReferendumVerifiable referendum = IAssetReferendumVerifiable(assetReferendum);
        assertTrue(referendum.isActive(assetId), "Asset should be active after approval");
        assertTrue(referendum.isApproved(submitter, assetId), "Submitter should have approved asset");
    }

    function testFuzz_SubmitAndReject(address submitter, uint256 assetId) public {
        vm.assume(submitter != address(0));
        vm.assume(submitter != contentCouncil);
        assetId = bound(assetId, 1, type(uint128).max);

        vm.prank(submitter);
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRevokable(assetReferendum).reject(assetId);

        IAssetReferendumVerifiable referendum = IAssetReferendumVerifiable(assetReferendum);
        assertFalse(referendum.isActive(assetId), "Rejected asset should be inactive");
        assertFalse(referendum.isApproved(submitter, assetId), "Rejected asset should not be approved");
    }

    function testFuzz_ApproveThenRevoke(address submitter, uint256 assetId) public {
        vm.assume(submitter != address(0));
        vm.assume(submitter != contentCouncil);
        assetId = bound(assetId, 1, type(uint128).max);

        vm.prank(submitter);
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRevokable(assetReferendum).revoke(assetId);

        IAssetReferendumVerifiable referendum = IAssetReferendumVerifiable(assetReferendum);
        assertFalse(referendum.isActive(assetId), "Revoked asset should not be active");
        assertFalse(referendum.isApproved(submitter, assetId), "Revoked asset should not be approved");
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

contract AssetReferendumInvariantTest is BaseTest {
    AssetReferendumHandler handler;

    function setUp() public initialize {
        deployAssetReferendum();

        handler = new AssetReferendumHandler(assetReferendum, contentCouncil);
        targetContract(address(handler));
    }

    function invariant_StateAlignment() external view {
        IAssetReferendumVerifiable referendum = IAssetReferendumVerifiable(assetReferendum);
        uint256 len = handler.trackedLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.trackedAt(i);
            AssetReferendumHandler.AssetState memory state = handler.stateOf(assetId);

            if (state.status == AssetReferendumHandler.Status.None) {
                continue;
            }

            bool isActive = referendum.isActive(assetId);
            bool isApproved = referendum.isApproved(state.submitter, assetId);

            if (state.status == AssetReferendumHandler.Status.Submitted) {
                assertFalse(isActive, "Submitted asset should be inactive");
                assertFalse(isApproved, "Submitted asset should not be approved");
            } else if (state.status == AssetReferendumHandler.Status.Approved) {
                assertTrue(isActive, "Approved asset should be active");
                assertTrue(isApproved, "Approved asset should be approved for submitter");
            } else if (state.status == AssetReferendumHandler.Status.Rejected) {
                assertFalse(isActive, "Rejected asset should be inactive");
                assertFalse(isApproved, "Rejected asset should not be approved");
            } else if (state.status == AssetReferendumHandler.Status.Revoked) {
                assertFalse(isActive, "Revoked asset should be inactive");
                assertFalse(isApproved, "Revoked asset should not be approved");
            }
        }
    }

    function invariant_NoApprovedWithoutSubmitter() external view {
        IAssetReferendumVerifiable referendum = IAssetReferendumVerifiable(assetReferendum);
        uint256 len = handler.trackedLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.trackedAt(i);
            AssetReferendumHandler.AssetState memory state = handler.stateOf(assetId);

            if (state.status == AssetReferendumHandler.Status.Approved) {
                assertTrue(state.submitter != address(0), "Approved asset must track submitter");
                assertTrue(referendum.isApproved(state.submitter, assetId), "Approved asset must stay approved");
            }
        }
    }
}
