// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAssetReferendumRegistrable } from "contracts/core/interfaces/assets/IAssetReferendumRegistrable.sol";
import { IAssetRegistry } from "contracts/core/interfaces/assets/IAssetRegistry.sol";
import { IAssetSafe } from "contracts/core/interfaces/assets/IAssetSafe.sol";
import { AssetSafe } from "contracts/assets/AssetSafe.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";

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
        IAssetSafe safe = IAssetSafe(assetSafe);
        safe.setContent(assetId, T.Cipher.LIT, "");
        assertEq(safe.getContent(assetId, T.Cipher.LIT), "", "Content should be set to empty string");
    }

    function test_SetContent_RevertIf_InvalidOwner() public {
        uint256 assetId = 123456;
        // registered to admin
        _registerAndApproveAsset(admin, assetId);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidAssetRightsHolder()"));
        IAssetSafe safe = IAssetSafe(assetSafe);
        safe.setContent(assetId, T.Cipher.LIT, "");
    }

    function test_SetContent_ContentEventEmitted() public {
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        vm.prank(user);
        vm.expectEmit(true, true, false, true, address(assetSafe));
        emit AssetSafe.ContentStored(assetId, user, T.Cipher.LIT);
        IAssetSafe safe = IAssetSafe(assetSafe);
        safe.setContent(assetId, T.Cipher.LIT, "");
    }

    function test_SetContent_MultipleCiphersUpdatesTypeOnly() public {
        uint256 assetId = 222;
        _registerAndApproveAsset(user, assetId);
        IAssetSafe safe = IAssetSafe(assetSafe);

        bytes memory litData = bytes("first");
        vm.prank(user);
        safe.setContent(assetId, T.Cipher.LIT, litData);

        bytes memory ecData = bytes("second");
        vm.prank(user);
        safe.setContent(assetId, T.Cipher.EC, ecData);

        // Latest cipher should be EC
        assertEq(uint8(safe.getType(assetId)), uint8(T.Cipher.EC), "Cipher type should reflect last write");
        // New cipher data stored
        assertEq(keccak256(safe.getContent(assetId, T.Cipher.EC)), keccak256(ecData), "EC payload mismatch");
        // Previous cipher data remains accessible
        assertEq(keccak256(safe.getContent(assetId, T.Cipher.LIT)), keccak256(litData), "LIT payload should remain");
    }

    function test_SetContent_ValidScheme() public {
        vm.warp(1641070800);
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetSafe safe = IAssetSafe(assetSafe);
        safe.setContent(assetId, T.Cipher.LIT, "");

        T.Cipher safeType = safe.getType(assetId);
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
        IAssetSafe safe = IAssetSafe(assetSafe);
        safe.setContent(assetId, T.Cipher.LIT, data);

        vm.prank(admin);
        bytes memory got = safe.getContent(assetId, T.Cipher.LIT);
        string memory expected = abi.decode(got, (string));
        assertEq(keccak256(abi.encodePacked(expected)), keccak256(abi.encodePacked(b64)), "Content should match the expected data");
    }

    function test_GetContent_ReturnsEmptyWhenNotSet() public view {
        IAssetSafe safe = IAssetSafe(assetSafe);
        bytes memory raw = safe.getContent(98765, T.Cipher.LIT);
        assertEq(raw.length, 0, "Unset content should return empty bytes");
    }

    function testFuzz_SetContent_StoresData(
        address owner,
        uint256 assetId,
        uint8 cipherSeed,
        uint256 dataSeed
    ) public {
        vm.assume(owner != address(0));
        assetId = bound(assetId, 1, type(uint128).max);

        _registerAndApproveAsset(owner, assetId);

        T.Cipher cipher = T.Cipher(uint8(bound(cipherSeed, 1, uint8(T.Cipher.EC))));
        bytes memory data = abi.encode(dataSeed);

        IAssetSafe safeContract = IAssetSafe(assetSafe);

        vm.prank(owner);
        safeContract.setContent(assetId, cipher, data);

        assertEq(uint8(safeContract.getType(assetId)), uint8(cipher), "Cipher type should match stored value");
        bytes memory stored = safeContract.getContent(assetId, cipher);
        assertEq(keccak256(stored), keccak256(data), "Stored content should match provided data");
    }

    function testFuzz_SetContent_RevertsForNonOwner(
        address owner,
        address attacker,
        uint256 assetId
    ) public {
        vm.assume(owner != address(0));
        vm.assume(attacker != address(0));
        vm.assume(attacker != owner);
        assetId = bound(assetId, 1, type(uint128).max);

        _registerAndApproveAsset(owner, assetId);

        vm.expectRevert(AssetSafe.InvalidAssetRightsHolder.selector);
        vm.prank(attacker);
        IAssetSafe(assetSafe).setContent(assetId, T.Cipher.LIT, "");
    }

    function _registerAndApproveAsset(address to, uint256 assetId) private {
        vm.prank(to);
        IAssetReferendumRegistrable(assetReferendum).submit(assetId);
        
        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(assetReferendum).approve(assetId);

        vm.prank(to);
        IAssetRegistry(assetRegistry).register(to, assetId);
    }
}
