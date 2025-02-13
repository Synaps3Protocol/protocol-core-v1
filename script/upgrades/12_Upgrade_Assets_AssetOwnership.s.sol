// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { AssetOwnership } from "contracts/assets/AssetOwnership.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeAssetOwnership is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address assetReferendum = vm.envAddress("ASSET_REFERENDUM");
        address impl = address(new AssetOwnership(assetReferendum));
        address assetOwnershipProxy = vm.envAddress("ASSET_OWNERSHIP");
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        // bytes memory init = abi.encodeCall(LedgerVaultV2.initializeV2, (accessManager));
        address assetOwnership = upgradeAndCallUUPS(assetOwnershipProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return assetOwnership;
    }
}
