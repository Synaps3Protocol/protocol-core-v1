// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AssetSafe } from "contracts/assets/AssetSafe.sol";

contract DeployAssetSafe is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address AssetOwnership = computeCreate3Address("SALT_ASSET_OWNERSHIP");
        address impl = address(new AssetSafe(AssetOwnership));
        bytes memory init = abi.encodeCall(AssetSafe.initialize, (accessManager));
        address assetVault = deployUUPS(impl, init, "SALT_ASSET_SAFE");
        vm.stopBroadcast();

        _checkExpectedAddress(assetVault, "SALT_ASSET_SAFE");
        _logAddress("ASSET_SAFE", assetVault);
        return assetVault;
    }
}
