// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { RightsPolicyAuthorizer } from "contracts/rights/RightsPolicyAuthorizer.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeRightsPolicyAuthorizer is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address policyAuditor = vm.envAddress("POLICY_AUDIT");
        address policyAuthorizerProxy = vm.envAddress("RIGHT_POLICY_AUTHORIZER");
        address impl = address(new RightsPolicyAuthorizer(policyAuditor));
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        // bytes memory init = abi.encodeCall(LedgerVaultV2.initializeV2, (accessManager));
        address rightPolicyAuthorizer = upgradeAndCallUUPS(policyAuthorizerProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return rightPolicyAuthorizer;
    }
}
