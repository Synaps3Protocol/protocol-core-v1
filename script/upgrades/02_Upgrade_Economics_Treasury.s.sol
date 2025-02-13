// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { Treasury } from "contracts/economics/Treasury.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeTreasury is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new Treasury());
        address treasuryProxy = vm.envAddress("TREASURY");
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        address treasury = upgradeAndCallUUPS(treasuryProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return treasury;
    }
}
