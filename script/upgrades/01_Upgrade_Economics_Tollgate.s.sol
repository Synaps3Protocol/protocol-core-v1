// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeTollgate is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new Tollgate());
        address tollgateProxy = vm.envAddress("TOLLGATE");
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        address tollgate = upgradeAndCallUUPS(tollgateProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return tollgate;
    }
}
