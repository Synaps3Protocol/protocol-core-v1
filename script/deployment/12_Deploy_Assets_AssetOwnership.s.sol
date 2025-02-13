// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AssetOwnership } from "contracts/assets/AssetOwnership.sol";

contract DeployAssetOwnership is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address assetReferendum = computeCreate3Address("SALT_ASSET_REFERENDUM");
        address impl = address(new AssetOwnership(assetReferendum));
        bytes memory init = abi.encodeCall(AssetOwnership.initialize, (accessManager));
        address assetOwnersip = deployUUPS(impl, init, "SALT_ASSET_OWNERSHIP");
        vm.stopBroadcast();
        
        _checkExpectedAddress(assetOwnersip, "SALT_ASSET_OWNERSHIP");
        _logAddress("ASSET_OWNERSHIP", assetOwnersip);
        return assetOwnersip;
    }
}
