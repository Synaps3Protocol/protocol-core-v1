// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { AgreementManager } from "contracts/financial/AgreementManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeAgreementManager is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address tollgateAddress = vm.envAddress("TOLLGATE");
        address ledgerVault = vm.envAddress("LEDGER_VAULT");
        address impl = address(new AgreementManager(tollgateAddress, ledgerVault));
        address agreementProxy = vm.envAddress("AGREEMENT_MANAGER");
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        // bytes memory init = abi.encodeCall(LedgerVaultV2.initializeV2, (accessManager));
        address agreementManager = upgradeAndCallUUPS(agreementProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return agreementManager;
    }
}
