// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { RightsPolicyAuthorizer } from "contracts/rightsmanager/RightsPolicyAuthorizer.sol";

contract DeployRightsPolicyAuthorizer is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address policyAudit = computeCreate3Address("SALT_POLICY_AUDIT");
        address impl = address(new RightsPolicyAuthorizer(policyAudit));
        bytes memory init = abi.encodeCall(RightsPolicyAuthorizer.initialize, (accessManager));
        address authorizer = deployUUPS(impl, init, "SALT_RIGHT_POLICY_AUTHORIZER");
        vm.stopBroadcast();

        _checkExpectedAddress(authorizer, "SALT_RIGHT_POLICY_AUTHORIZER");
        _logAddress("RIGHT_POLICY_AUTHORIZER", authorizer);
        return authorizer;
    }
}
