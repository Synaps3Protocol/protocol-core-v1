// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { PolicyAudit } from "contracts/policies/PolicyAudit.sol";
import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract DeployPolicyAudit is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new PolicyAudit());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(PolicyAudit.initialize, (accessManager));
        address policyAudit = deployUUPS(impl, init, "SALT_POLICY_AUDIT");
        vm.stopBroadcast();

        _checkExpectedAddress(policyAudit, "SALT_POLICY_AUDIT");
        _logAddress("POLICY_AUDIT", policyAudit);
        return policyAudit;
    }
}
