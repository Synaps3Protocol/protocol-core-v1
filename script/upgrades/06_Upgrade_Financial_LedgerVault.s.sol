// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { LedgerVault } from "contracts/financial/LedgerVault.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeLedgerVault is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new LedgerVault());
        address ledgerProxy = vm.envAddress("LEDGER_VAULT");
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        // bytes memory init = abi.encodeCall(LedgerVaultV2.initializeV2, (accessManager));
        address ledgerVault = upgradeAndCallUUPS(ledgerProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return ledgerVault;
    }
}
