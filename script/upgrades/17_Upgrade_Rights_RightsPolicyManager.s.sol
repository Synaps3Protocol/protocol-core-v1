// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UpgradeBase } from "script/upgrades/00_Upgrade_Base.s.sol";
import { RightsPolicyManager } from "contracts/rights/RightsPolicyManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract UpgradeRightsPolicyManager is UpgradeBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address agreementSettler = vm.envAddress("AGREEMENT_SETTLER");
        address rightAuthorizer = vm.envAddress("RIGHT_POLICY_AUTHORIZER");
        address policyManagerProxy = vm.envAddress("RIGHT_POLICY_MANAGER");
        address impl = address(new RightsPolicyManager(agreementSettler, rightAuthorizer));
        // address accessManager = vm.envAddress("ACCESS_MANAGER");
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        // bytes memory init = abi.encodeCall(LedgerVaultV2.initializeV2, (accessManager));
        address rightPolicyManager = upgradeAndCallUUPS(policyManagerProxy, impl, ""); // no initialization
        vm.stopBroadcast();
        return rightPolicyManager;
    }
}
