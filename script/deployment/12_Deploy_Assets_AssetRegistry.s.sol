// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AssetRegistry } from "contracts/assets/AssetRegistry.sol";

contract DeployAssetRegistry is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getDeployerPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address assetReferendum = computeCreate3Address("SALT_ASSET_REFERENDUM");
        address impl = address(new AssetRegistry(assetReferendum));
        bytes memory init = abi.encodeCall(AssetRegistry.initialize, (accessManager));
        address assetRegistry = deployUUPS(impl, init, "SALT_ASSET_REGISTRY");
        vm.stopBroadcast();

        _checkExpectedAddress(assetRegistry, "SALT_ASSET_REGISTRY");
        _logAddress("ASSET_REGISTRY", assetRegistry);
        return assetRegistry;
    }
}
