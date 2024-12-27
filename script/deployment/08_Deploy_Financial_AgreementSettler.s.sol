// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AgreementSettler } from "contracts/financial/AgreementSettler.sol";

contract DeployAgreementSettler is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address treasury = computeCreate3Address("SALT_TREASURY");
        address vault = computeCreate3Address("SALT_LEDGER_VAULT");
        address agreementManager = computeCreate3Address("SALT_AGREEMENT_MANAGER");
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address impl = address(new AgreementSettler(treasury, agreementManager, vault));
        bytes memory init = abi.encodeCall(AgreementSettler.initialize, (accessManager));
        address settler = deployUUPS(impl, init, "SALT_AGREEMENT_SETTLER");
        vm.stopBroadcast();

        _checkExpectedAddress(settler, "SALT_AGREEMENT_SETTLER");
        _logAddress("AGREEMENT_SETTLER", settler);
        return settler;
    }
}
