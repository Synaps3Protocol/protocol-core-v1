// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetRegistrable } from "contracts/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "contracts/core/interfaces/assets/IAssetVerifiable.sol";
import { IAssetOwnership } from "contracts/core/interfaces/assets/IAssetOwnership.sol";
import { IAssetSafe } from "contracts/core/interfaces/assets/IAssetSafe.sol";
import { AssetSafe } from "contracts/assets/AssetSafe.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract AssetSafeTest is BaseTest {


    function setUp() public initialize {
        // setup the access manager to use during tests..
        deployAssetSafe();
        
    }

    function test_SetContent_ValidOwner() public {
        vm.warp(1641070800);
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetSafe assetSafe = IAssetSafe(assetSafe);
        assetSafe.setContent(assetId, T.Cipher.LIT, "");
        assertEq(assetSafe.getContent(assetId, T.Cipher.LIT), "", "Content should be set to empty string");
    }

    function test_SetContent_RevertIf_InvalidOwner() public {
        uint256 assetId = 123456;
        // registered to admin
        _registerAndApproveAsset(admin, assetId);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidAssetRightsHolder()"));
        IAssetSafe assetSafe = IAssetSafe(assetSafe);
        assetSafe.setContent(assetId, T.Cipher.LIT, "");
    }

    function test_SetContent_ContentEventEmitted() public {
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        vm.prank(user);
        vm.expectEmit(true, true, false, true, address(assetSafe));
        emit AssetSafe.ContentStored(assetId, user, T.Cipher.LIT);
        IAssetSafe assetSafe = IAssetSafe(assetSafe);
        assetSafe.setContent(assetId, T.Cipher.LIT, "");
    }

    function test_SetContent_ValidScheme() public {
        vm.warp(1641070800);
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetSafe assetSafe = IAssetSafe(assetSafe);
        assetSafe.setContent(assetId, T.Cipher.LIT, "");

        T.Cipher safeType = assetSafe.getType(assetId);
        assertEq(uint256(safeType), uint256(T.Cipher.LIT), "Safe type should be LIT");
    }

    function test_GetContent_ValidStoredData() public {
        vm.warp(1641070800);
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        // we could use the safe to store and share data seamlessly:
        // this data is required by lit to decrypt the data:
        // - lit accessControlConditions
        // - lit dataToEncryptHash
        // - the encrypted content stored elsewhere

        // these are test purpose data no real data
        // format: b64(conditions).b64(hash)
        string memory b64 = "W3siY2hhaW4iOiJldGhlcmV1bSIsImNvbnRyYWN0QWR.NDU2Nzg5MGFiY2RQ1Njc4OTBhYmNk";
        bytes memory data = abi.encode(b64);

        vm.prank(user);
        IAssetSafe assetSafe = IAssetSafe(assetSafe);
        assetSafe.setContent(assetId, T.Cipher.LIT, data);

        vm.prank(admin);
        bytes memory got = assetSafe.getContent(assetId, T.Cipher.LIT);
        string memory expected = abi.decode(got, (string));
        assertEq(keccak256(abi.encodePacked(expected)), keccak256(abi.encodePacked(b64)), "Content should match the expected data");
    }

    function _registerAndApproveAsset(address to, uint256 assetId) private {
        vm.prank(to);
        IAssetRegistrable(assetReferendum).submit(assetId);
        vm.prank(governor);
        IAssetRegistrable(assetReferendum).approve(assetId);

        vm.prank(to);
        IAssetOwnership(assetOwnership).register(to, assetId);
    }
}
