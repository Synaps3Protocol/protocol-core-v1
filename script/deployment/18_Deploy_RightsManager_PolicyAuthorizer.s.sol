// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { RightsPolicyAuthorizer } from "contracts/rights/RightsPolicyAuthorizer.sol";

/// @notice Local deployment helper for test environments.
/// @dev Mirrors the production deployment but allows injecting custom dependencies when needed.
contract DeployRightsPolicyAuthorizer is DeployBase {
    function run(address policyAudit, address accessManager) external returns (address) {
        vm.startBroadcast(getAdminPK());

        address implementation = address(new RightsPolicyAuthorizer(policyAudit));
        bytes memory initData = abi.encodeCall(RightsPolicyAuthorizer.initialize, accessManager);
        address proxy = deployUUPS(implementation, initData, "SALT_RIGHT_POLICY_AUTHORIZER");

        vm.stopBroadcast();
        return proxy;
    }
}

