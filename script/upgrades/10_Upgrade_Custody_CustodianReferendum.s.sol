// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { CustodianReferendum } from "contracts/custody/CustodianReferendum.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeCustodianReferendum is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address treasuryAddress = vm.envAddress("TREASURY");
        address tollgateAddress = vm.envAddress("TOLLGATE");
        address ledgerVault = vm.envAddress("LEDGER_VAULT");
        address impl = address(new CustodianReferendum(treasuryAddress, tollgateAddress, ledgerVault));
        address referendumProxy = vm.envAddress("CUSTODIAN_REFERENDUM");
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        // bytes memory init = abi.encodeCall(LedgerVaultV2.initializeV2, (accessManager));
        address custodianReferendum = upgradeAndCallUUPS(referendumProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return custodianReferendum;
    }
}
