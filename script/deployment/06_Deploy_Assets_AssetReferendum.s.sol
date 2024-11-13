// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AssetReferendum } from "contracts/assets/AssetReferendum.sol";

contract DeployAssetReferendum is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new AssetReferendum());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(AssetReferendum.initialize, (accessManager));
        address assetReferendum = deployUUPS(impl, init, "SALT_CONTENT_REFERENDUM");
        vm.stopBroadcast();

        _checkExpectedAddress(assetReferendum, "SALT_CONTENT_REFERENDUM");
        _logAddress("CONTENT_REFERENDUM", assetReferendum);
        return assetReferendum;
    }
}
