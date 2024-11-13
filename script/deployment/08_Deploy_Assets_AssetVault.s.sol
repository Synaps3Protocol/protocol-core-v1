// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AssetVault } from "contracts/assets/AssetVault.sol";

contract DeployAssetVault is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address AssetOwnership = computeCreate3Address("SALT_ASSET_OWNERSHIP");
        address impl = address(new AssetVault(AssetOwnership));
        bytes memory init = abi.encodeCall(AssetVault.initialize, (accessManager));
        address assetVault = deployUUPS(impl, init, "SALT_ASSET_VAULT");
        vm.stopBroadcast();

        _checkExpectedAddress(assetVault, "SALT_ASSET_VAULT");
        _logAddress("ASSET_VAULT", assetVault);
        return assetVault;
    }
}
