// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { AssetRegistry } from "contracts/assets/AssetRegistry.sol";
import { IAssetRegistry } from "contracts/core/interfaces/assets/IAssetRegistry.sol";
import { IAssetReferendumRegistrable } from "contracts/core/interfaces/assets/IAssetReferendumRegistrable.sol";
import { IERC721StatefulVerifiable } from "contracts/core/interfaces/token/erc721/IERC721StatefulVerifiable.sol";
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import { BaseTest } from "test/BaseTest.t.sol";

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
        assertTrue(IERC721StatefulVerifiable(assetRegistry).isActive(assetId), "Asset must be active");
        assertEq(AssetRegistry(assetRegistry).totalSupply(), 1, "Total supply should reflect minted asset");
        assertEq(IAssetRegistry(assetRegistry).balanceOf(user), 1, "Owner balance should increment");
    }

    function test_Register_RevertWhen_NotApproved() public {
        uint256 assetId = 11;

        vm.expectRevert(AssetRegistry.InvalidNotApprovedAsset.selector);
        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);
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

    function test_SwitchState_RevertWhen_NotOwner() public {
        uint256 assetId = 52;
        address stranger = vm.addr(777);

        _submitAndApproveAsset(user, assetId);
        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidUnauthorizedOperation(string)",
                "Only the asset owner can modify its state."
            )
        );
        vm.prank(stranger);
        AssetRegistry(assetRegistry).switchState(assetId);
    }

    function test_Revoke_DisablesAndBurns() public {
        uint256 assetId = 61;
        _submitAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectEmit(true, true, false, true, assetRegistry);
        emit AssetRegistry.RevokedAsset(user, assetId);

        vm.prank(governor);
        IAssetRegistry(assetRegistry).revoke(assetId);

        assertFalse(IERC721StatefulVerifiable(assetRegistry).isActive(assetId), "Revoked asset should be inactive");
        assertEq(AssetRegistry(assetRegistry).totalSupply(), 0, "Total supply should decrease after burn");

        vm.expectRevert();
        IAssetRegistry(assetRegistry).ownerOf(assetId);
    }

    function test_Revoke_RevertWhen_NotAdmin() public {
        uint256 assetId = 71;
        _submitAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetRegistry(assetRegistry).register(user, assetId);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, user));
        vm.prank(user);
        AssetRegistry(assetRegistry).revoke(assetId);
    }

    function _submitAndApproveAsset(address submitter, uint256 assetId) private {
        vm.prank(submitter);
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);
    }
}
