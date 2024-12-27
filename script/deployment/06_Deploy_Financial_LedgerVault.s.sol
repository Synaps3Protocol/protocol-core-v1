// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { LedgerVault } from "contracts/financial/LedgerVault.sol";

contract DeployLedgerVault is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address impl = address(new LedgerVault());
        bytes memory init = abi.encodeCall(LedgerVault.initialize, (accessManager));
        address ledger = deployUUPS(impl, init, "SALT_LEDGER_VAULT");
        vm.stopBroadcast();

        _checkExpectedAddress(ledger, "SALT_LEDGER_VAULT");
        _logAddress("LEDGER_VAULT", ledger);
        return ledger;
    }
}
