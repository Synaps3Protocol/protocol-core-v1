// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { RightsPolicyManager } from "contracts/rights/RightsPolicyManager.sol";

contract DeployRightsPolicyManager is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address agreementSettler = computeCreate3Address("SALT_AGREEMENT_SETTLER");
        address rightsAuthorizer = computeCreate3Address("SALT_RIGHT_POLICY_AUTHORIZER");
        address impl = address(new RightsPolicyManager(agreementSettler, rightsAuthorizer));
        bytes memory init = abi.encodeCall(RightsPolicyManager.initialize, (accessManager));
        address manager = deployUUPS(impl, init, "SALT_RIGHT_POLICY_MANAGER");
        vm.stopBroadcast();

        _checkExpectedAddress(manager, "SALT_RIGHT_POLICY_MANAGER");
        _logAddress("RIGHT_POLICY_MANAGER", manager);
        return manager;
    }
}
