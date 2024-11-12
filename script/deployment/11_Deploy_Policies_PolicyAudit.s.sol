// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { PolicyAudit } from "contracts/policies/PolicyAudit.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { C } from "contracts/libraries/Constants.sol";

contract DeployPolicyAudit is DeployBase {
    function getGovPermissions() public pure returns (bytes4[] memory) {
        // tollgate grant access to governacne
        // IAccessManager authority = IAccessManager(computeCreate3Address("SALT_ACCESS_MANAGER"));
        // address policyAudit = computeCreate3Address("SALT_POLICY_AUDIT");
        // tollgate grant access to collectors
        bytes4[] memory auditorAllowed = new bytes4[](2);
        auditorAllowed[0] = PolicyAudit.approve.selector;
        auditorAllowed[1] = PolicyAudit.reject.selector;
        return auditorAllowed;
    }

    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new PolicyAudit());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(PolicyAudit.initialize, (accessManager));
        address policyAudit = deployUUPS(impl, init, "SALT_POLICY_AUDIT");
        vm.stopBroadcast();

        _checkExpectedAddress(policyAudit, "SALT_POLICY_AUDIT");
        return policyAudit;
    }
}
