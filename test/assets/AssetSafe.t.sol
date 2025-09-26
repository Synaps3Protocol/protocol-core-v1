// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IAssetReferendumRegistrable } from "contracts/core/interfaces/assets/IAssetReferendumRegistrable.sol";
import { IAssetRegistry } from "contracts/core/interfaces/assets/IAssetRegistry.sol";
import { IAssetSafe } from "contracts/core/interfaces/assets/IAssetSafe.sol";
import { AssetSafe } from "contracts/assets/AssetSafe.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";

contract AssetSafeHandler is Test {
    address public immutable safe;
    address public immutable registry;
    address public immutable referendum;
    address public immutable contentCouncil;

    address[] public actors;

    uint256[] private _assetIds;
    mapping(uint256 => bool) private _isTracked;
    mapping(uint256 => address) private _owners;
    mapping(uint256 => mapping(uint8 => bytes)) private _content;
    mapping(uint256 => mapping(uint8 => bool)) private _hasContent;
    mapping(uint256 => uint8) private _latestCipher;
    mapping(uint256 => bool) private _hasLatestCipher;

    constructor(address safe_, address registry_, address referendum_, address contentCouncil_) {
        safe = safe_;
        registry = registry_;
        referendum = referendum_;
        contentCouncil = contentCouncil_;

        for (uint256 i = 0; i < 6; i++) {
            actors.push(vm.addr(i + 501));
        }
    }

    function registerAsset(uint256 assetSeed, uint256 actorSeed) external {
        if (actors.length == 0) return;

        uint256 assetId = bound(assetSeed, 1, type(uint128).max);
        if (_isTracked[assetId]) return;

        address owner = actors[actorSeed % actors.length];
        if (owner == address(0)) return;

        vm.prank(owner);
        IAssetReferendumRegistrable(referendum).submit(assetId);

        vm.prank(contentCouncil);
        IAssetReferendumRegistrable(referendum).approve(assetId);

        vm.prank(owner);
        IAssetRegistry(registry).register(owner, assetId);

        _isTracked[assetId] = true;
        _owners[assetId] = owner;
        _assetIds.push(assetId);
    }

    function transferAsset(uint256 assetSeed, uint256 actorSeed) external {
        if (_assetIds.length == 0) return;

        uint256 assetId = _assetIds[assetSeed % _assetIds.length];
        if (!_isTracked[assetId]) return;

        address currentOwner = _owners[assetId];
        if (currentOwner == address(0)) return;

        address newOwner = actors[actorSeed % actors.length];
        if (newOwner == address(0) || newOwner == currentOwner) return;

        vm.prank(currentOwner);
        IAssetRegistry(registry).transfer(newOwner, assetId);

        _owners[assetId] = newOwner;
    }

    function setContent(uint256 assetSeed, uint8 cipherSeed, uint256 dataSeed) external {
        if (_assetIds.length == 0) return;

        uint256 assetId = _assetIds[assetSeed % _assetIds.length];
        if (!_isTracked[assetId]) return;

        address owner = _owners[assetId];
        if (owner == address(0)) return;

        uint8 cipherIndex = uint8(bound(cipherSeed, 1, uint8(T.Cipher.EC)));
        T.Cipher cipher = T.Cipher(cipherIndex);
        bytes memory data = abi.encode(dataSeed);

        vm.prank(owner);
        IAssetSafe(safe).setContent(assetId, cipher, data);

        _content[assetId][cipherIndex] = data;
        _hasContent[assetId][cipherIndex] = true;
        _latestCipher[assetId] = cipherIndex;
        _hasLatestCipher[assetId] = true;
    }

    function trackedLength() external view returns (uint256) {
        return _assetIds.length;
    }

    function trackedAt(uint256 index) external view returns (uint256) {
        return _assetIds[index];
    }

    function ownerOf(uint256 assetId) external view returns (address) {
        return _owners[assetId];
    }

    function isTracked(uint256 assetId) external view returns (bool) {
        return _isTracked[assetId];
    }

    function hasContent(uint256 assetId, uint8 cipherIndex) external view returns (bool) {
        return _hasContent[assetId][cipherIndex];
    }

    function contentOf(uint256 assetId, uint8 cipherIndex) external view returns (bytes memory) {
        return _content[assetId][cipherIndex];
    }

    function hasLatestCipher(uint256 assetId) external view returns (bool) {
        return _hasLatestCipher[assetId];
    }

    function latestCipher(uint256 assetId) external view returns (uint8) {
        return _latestCipher[assetId];
    }
}

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

contract AssetSafeInvariantTest is BaseTest {
    AssetSafeHandler handler;
    uint8 private constant MAX_CIPHER = uint8(T.Cipher.EC);

    function setUp() public initialize {
        deployAssetSafe();

        handler = new AssetSafeHandler(assetSafe, assetRegistry, assetReferendum, contentCouncil);
        targetContract(address(handler));
    }

    function invariant_OwnerMatchesRegistry() external view {
        IAssetRegistry registryContract = IAssetRegistry(assetRegistry);
        uint256 len = handler.trackedLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.trackedAt(i);
            if (!handler.isTracked(assetId)) {
                continue;
            }

            address expectedOwner = handler.ownerOf(assetId);
            if (expectedOwner == address(0)) {
                continue;
            }

            assertEq(registryContract.ownerOf(assetId), expectedOwner, "Handler owner should match registry owner");
        }
    }

    function invariant_ContentMatchesStored() external view {
        IAssetSafe safeContract = IAssetSafe(assetSafe);
        uint256 len = handler.trackedLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.trackedAt(i);

            for (uint8 cipherIndex = 1; cipherIndex <= MAX_CIPHER; cipherIndex++) {
                if (!handler.hasContent(assetId, cipherIndex)) {
                    continue;
                }

                bytes memory expected = handler.contentOf(assetId, cipherIndex);
                bytes memory actual = safeContract.getContent(assetId, T.Cipher(cipherIndex));
                assertEq(keccak256(actual), keccak256(expected), "Stored content should match handler state");
            }
        }
    }

    function invariant_LatestCipherMatchesType() external view {
        IAssetSafe safeContract = IAssetSafe(assetSafe);
        uint256 len = handler.trackedLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 assetId = handler.trackedAt(i);
            if (!handler.hasLatestCipher(assetId)) {
                continue;
            }

            uint8 expected = handler.latestCipher(assetId);
            assertEq(uint8(safeContract.getType(assetId)), expected, "Latest cipher should match stored type");
        }
    }
}
