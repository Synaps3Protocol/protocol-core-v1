// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { AssetRegistry } from "contracts/assets/AssetRegistry.sol";
import { IAssetRegistry } from "contracts/core/interfaces/assets/IAssetRegistry.sol";
import { IAssetReferendumRegistrable } from "contracts/core/interfaces/assets/IAssetReferendumRegistrable.sol";
import { IERC721StatefulVerifiable } from "contracts/core/interfaces/token/erc721/IERC721StatefulVerifiable.sol";

import { BaseTest } from "test/BaseTest.t.sol";

contract AssetRegistryHandler is Test {
    struct AssetInfo {
        bool exists;
        bool revoked;
        bool active;
        address owner;
    }

    AssetRegistry public registry;
    address public referendum;
    address public contentCouncil;
    address public admin;
    address[] public actors;

    uint256[] private _assetIds;
    mapping(uint256 => AssetInfo) private _assets;

    constructor(address registry_, address referendum_, address contentCouncil_, address admin_) {
        registry = AssetRegistry(registry_);
        referendum = referendum_;
        contentCouncil = contentCouncil_;
        admin = admin_;

        actors.push(contentCouncil_);
        for (uint256 i = 0; i < 5; i++) {
            actors.push(vm.addr(i + 100));
        }
    }

    function register(uint256 assetSeed, uint256 actorSeed) external {
        if (actors.length == 0) return;

        uint256 assetId = bound(assetSeed, 1, type(uint128).max);
        AssetInfo storage info = _assets[assetId];
        if (info.exists) return;

        address submitter = actors[actorSeed % actors.length];

        vm.prank(submitter);
        IAssetReferendumRegistrable(referendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(referendum).approve(assetId);

        vm.prank(submitter);
        registry.register(submitter, assetId);

        info.exists = true;
        info.revoked = false;
        info.active = true;
        info.owner = submitter;
        _assetIds.push(assetId);
    }

    function transfer(uint256 tokenSeed, uint256 targetSeed) external {
        if (_assetIds.length == 0) return;

        uint256 assetId = _assetIds[tokenSeed % _assetIds.length];
        AssetInfo storage info = _assets[assetId];
        if (!info.exists || info.revoked) return;

        address newOwner = actors[targetSeed % actors.length];
        if (newOwner == address(0) || newOwner == info.owner) return;

        vm.prank(info.owner);
        registry.transfer(newOwner, assetId);

        info.owner = newOwner;
    }

    function switchState(uint256 tokenSeed) external {
        if (_assetIds.length == 0) return;

        uint256 assetId = _assetIds[tokenSeed % _assetIds.length];
        AssetInfo storage info = _assets[assetId];
        if (!info.exists || info.revoked) return;

        vm.prank(info.owner);
        bool newState = registry.switchState(assetId);
        info.active = newState;
    }

    function revoke(uint256 tokenSeed) external {
        if (_assetIds.length == 0) return;

        uint256 assetId = _assetIds[tokenSeed % _assetIds.length];
        AssetInfo storage info = _assets[assetId];
        if (!info.exists || info.revoked) return;

        vm.prank(admin);
        registry.revoke(assetId);

        info.revoked = true;
        info.active = false;
        info.owner = address(0);
    }

    function assetIdsLength() external view returns (uint256) {
        return _assetIds.length;
    }

    function assetIdAt(uint256 index) external view returns (uint256) {
        return _assetIds[index];
    }

    function getAssetInfo(uint256 assetId) external view returns (AssetInfo memory) {
        return _assets[assetId];
    }
}

contract AssetRegistryTest is BaseTest {
    function setUp() public initialize {
        // setup the access manager to use during tests..
        deployAssetRegistry();
    }

    function test_Register_ValidRegistration() public {
        uint256 assetId = 1;

        _submitAndApproveAsset(user, assetId);

        vm.expectEmit(false, false, false, true, assetRegistry);
        emit AssetRegistry.AssetEnabled(assetId);

        vm.expectEmit(true, true, false, true, assetRegistry);
        emit AssetRegistry.RegisteredAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        assertEq(IAssetRegistry(assetRegistry).ownerOf(assetId), user, "Invalid unexpected owner");
        assertEq(IERC721StatefulVerifiable(assetRegistry).isActive(assetId), true, "Asset must be active");
    }

    function test_Register_RevertWhen_NotApproved() public {
        uint256 assetId = 11;

        vm.expectRevert(AssetRegistry.InvalidNotApprovedAsset.selector);
        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);
    }

    function testFuzz_Register_SetsOwnerAndActivates(address to, uint256 assetId) public {
        vm.assume(to != address(0));
        assetId = bound(assetId, 1, type(uint128).max);

        _submitAndApproveAsset(to, assetId);

        vm.prank(to);
        IAssetRegistry(assetRegistry).register(to, assetId);

        assertEq(IAssetRegistry(assetRegistry).ownerOf(assetId), to, "Unexpected owner after register");
        assertTrue(IERC721StatefulVerifiable(assetRegistry).isActive(assetId), "Asset should be active");
        assertEq(IAssetRegistry(assetRegistry).balanceOf(to), 1, "Balance should account for minted asset");
        assertEq(AssetRegistry(assetRegistry).totalSupply(), 1, "Total supply should match minted assets");
    }

    function test_Register_RevertWhen_DuplicateAsset() public {
        uint256 assetId = 21;
        _submitAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectRevert();
        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);
    }

    function test_Transfer_ValidOwner() public {
        uint256 assetId = 31;
        address recipient = vm.addr(33);

        _submitAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectEmit(true, true, false, true, assetRegistry);
        emit AssetRegistry.TransferredAsset(user, recipient, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).transfer(recipient, assetId);

        assertEq(IAssetRegistry(assetRegistry).ownerOf(assetId), recipient, "Recipient must own the asset");
    }

    function test_Transfer_RevertWhen_NotOwner() public {
        uint256 assetId = 41;
        address recipient = vm.addr(34);

        _submitAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectRevert(abi.encodeWithSignature("InvalidUnauthorizedOperation(string)", "Only the asset owner can modify its state."));
        vm.prank(recipient);
        IAssetRegistry(assetRegistry).transfer(recipient, assetId);
    }

    function test_SwitchState_Toggles() public {
        uint256 assetId = 51;
        _submitAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectEmit(false, false, false, true, assetRegistry);
        emit AssetRegistry.AssetDisabled(assetId);

        vm.prank(user);
        bool newState = AssetRegistry(assetRegistry).switchState(assetId);
        assertFalse(newState, "Asset should be disabled after first toggle");
        assertFalse(IERC721StatefulVerifiable(assetRegistry).isActive(assetId), "Asset should be inactive");

        vm.expectEmit(false, false, false, true, assetRegistry);
        emit AssetRegistry.AssetEnabled(assetId);

        vm.prank(user);
        bool backToActive = AssetRegistry(assetRegistry).switchState(assetId);
        assertTrue(backToActive, "Asset should be active after second toggle");
        assertTrue(IERC721StatefulVerifiable(assetRegistry).isActive(assetId), "Asset should be active again");
    }

    function test_Revoke_DisablesAndBurns() public {
        uint256 assetId = 61;
        _submitAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectEmit(true, true, false, true, assetRegistry);
        emit AssetRegistry.RevokedAsset(user, assetId);

        vm.prank(admin);
        AssetRegistry(assetRegistry).revoke(assetId);

        assertFalse(IERC721StatefulVerifiable(assetRegistry).isActive(assetId), "Revoked asset should be inactive");
        assertEq(AssetRegistry(assetRegistry).totalSupply(), 0, "Total supply should decrease after burn");

        vm.expectRevert();
        IAssetRegistry(assetRegistry).ownerOf(assetId);
    }

    function _submitAndApproveAsset(address submitter, uint256 assetId) private {
        vm.prank(submitter);
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);
    }
}

contract AssetRegistryInvariantTest is BaseTest {
    AssetRegistryHandler handler;

    function setUp() public initialize {
        deployAssetRegistry();

        handler = new AssetRegistryHandler(assetRegistry, assetReferendum, contentCouncil, admin);
        targetContract(address(handler));
    }

    function invariant_TotalSupplyMatchesTracked() external view {
        uint256 len = handler.assetIdsLength();
        uint256 expectedSupply = 0;

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.assetIdAt(i);
            AssetRegistryHandler.AssetInfo memory info = handler.getAssetInfo(assetId);
            if (info.exists && !info.revoked) {
                expectedSupply++;
            }
        }

        assertEq(AssetRegistry(assetRegistry).totalSupply(), expectedSupply, "Total supply mismatch");
    }

    function invariant_TrackedOwnerMatchesRegistry() external view {
        uint256 len = handler.assetIdsLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.assetIdAt(i);
            AssetRegistryHandler.AssetInfo memory info = handler.getAssetInfo(assetId);

            if (!info.exists || info.revoked) {
                continue;
            }

            assertEq(info.owner, IAssetRegistry(assetRegistry).ownerOf(assetId), "Tracked owner mismatch");
            assertTrue(info.owner != address(0), "Active asset cannot have zero owner");
        }
    }

    function invariant_ActiveFlagMatchesRegistryState() external view {
        uint256 len = handler.assetIdsLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.assetIdAt(i);
            AssetRegistryHandler.AssetInfo memory info = handler.getAssetInfo(assetId);

            if (!info.exists) {
                continue;
            }

            bool isActiveOnChain = IERC721StatefulVerifiable(assetRegistry).isActive(assetId);

            if (info.revoked) {
                assertFalse(isActiveOnChain, "Revoked asset should be inactive on chain");
            } else {
                assertEq(isActiveOnChain, info.active, "Active flag mismatch");
            }
        }
    }
}
