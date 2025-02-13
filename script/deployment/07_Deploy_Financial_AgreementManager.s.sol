// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AgreementManager } from "contracts/financial/AgreementManager.sol";

contract DeployAgreementManager is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address tollgate = computeCreate3Address("SALT_TOLLGATE");
        address vault = computeCreate3Address("SALT_LEDGER_VAULT");
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address impl = address(new AgreementManager(tollgate, vault));
        bytes memory init = abi.encodeCall(AgreementManager.initialize, (accessManager));
        address agreement = deployUUPS(impl, init, "SALT_AGREEMENT_MANAGER");
        vm.stopBroadcast();

        _checkExpectedAddress(agreement, "SALT_AGREEMENT_MANAGER");
        _logAddress("AGREEMENT_MANAGER", agreement);
        return agreement;
    }
}
