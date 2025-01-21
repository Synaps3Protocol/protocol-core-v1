// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { LedgerVaultV2 } from "contracts/financial/upgrades/ledger/LedgerVaultV2.sol";
import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeLedgerVaultV2 is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new LedgerVaultV2());
        address ledgerProxy = vm.envAddress("LEDGER_VAULT");
        address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        bytes memory init = abi.encodeCall(LedgerVaultV2.initializeV2, (accessManager));
        address ledgerVault = upgradeAndCallUUPS(ledgerProxy, impl, init);
        vm.stopBroadcast();
        return ledgerVault;
    }
}
