// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAssetRegistrable } from "contracts/core/interfaces/assets/IAssetRegistrable.sol";
import { IAssetVerifiable } from "contracts/core/interfaces/assets/IAssetVerifiable.sol";
import { IAssetOwnership } from "contracts/core/interfaces/assets/IAssetOwnership.sol";
import { IAssetVault } from "contracts/core/interfaces/assets/IAssetVault.sol";
import { AssetVault } from "contracts/assets/AssetVault.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract AssetVaultTest is BaseTest {
    address vault;
    address ownership;
    address referendum;

    function setUp() public initialize {
        // setup the access manager to use during tests..
        vault = deployAssetVault();
        ownership = deployAssetOwnership();
        referendum = deployAssetReferendum();
    }

    function test_SetContent_ExpectedOwner() public {
        vm.warp(1641070800);
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        vm.prank(user);
        IAssetVault assetVault = IAssetVault(vault);
        assetVault.setContent(assetId, T.VaultType.LIT, "");
    }

    function test_SetContent_ContentEventEmitted() public {
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        vm.prank(user);
        vm.expectEmit(true, true, false, true, address(vault));
        emit AssetVault.ContentStored(assetId, user, T.VaultType.LIT);
        IAssetVault assetVault = IAssetVault(vault);
        assetVault.setContent(assetId, T.VaultType.LIT, "");
    }

    function test_SetContent_RevertIf_InvalidOwner() public {
        uint256 assetId = 123456;
        // registered to admin
        _registerAndApproveAsset(admin, assetId);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidAssetRightsHolder()"));
        IAssetVault assetVault = IAssetVault(vault);
        assetVault.setContent(assetId, T.VaultType.LIT, "");
    }

    function test_GetContent_ValidStoredData() public {
        vm.warp(1641070800);
        uint256 assetId = 123456;
        _registerAndApproveAsset(user, assetId);

        // we could use the vault to store and share data seamlessly:
        // this data is required by lit to decrypt the data:
        // - lit accessControlConditions
        // - lit dataToEncryptHash
        // - the encrypted content stored elsewhere

        // these are test purpose data no real data
        // format: b64(conditions).b64(hash)
        string memory b64 = "W3siY2hhaW4iOiJldGhlcmV1bSIsImNvbnRyYWN0QWR.NDU2Nzg5MGFiY2RQ1Njc4OTBhYmNk";
        bytes memory data = abi.encode(b64);

        vm.prank(user);
        IAssetVault assetVault = IAssetVault(vault);
        assetVault.setContent(assetId, T.VaultType.LIT, data);

        vm.prank(admin);
        bytes memory got = assetVault.getContent(assetId, T.VaultType.LIT);
        string memory expected = abi.decode(got, (string));
        assert(keccak256(abi.encodePacked(expected)) == keccak256(abi.encodePacked(b64)));
    }

    function _registerAndApproveAsset(address to, uint256 assetId) private {
        vm.prank(to);
        IAssetRegistrable(referendum).submit(assetId);
        vm.prank(governor);
        IAssetRegistrable(referendum).approve(assetId);

        vm.prank(to);
        IAssetOwnership(ownership).claim(to, assetId);
    }
}
