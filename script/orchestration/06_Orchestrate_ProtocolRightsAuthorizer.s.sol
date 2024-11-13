// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { IRightsPolicyAuthorizer } from "contracts/interfaces/rightsmanager/IRightsPolicyAuthorizer.sol";

contract OrchestrateRightsAuthorizer is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address mmc = vm.envAddress("MMC");
        address rightsAuthorizer = vm.envAddress("RIGHT_POLICY_AUTHORIZER");
        address subscriptionPolicy = vm.envAddress("SUBSCRIPTION_POLICY");

        vm.startBroadcast(admin);
        // approve initial distributor
        IRightsPolicyAuthorizer custodian = IRightsPolicyAuthorizer(rightsAuthorizer);
        custodian.authorizePolicy(subscriptionPolicy, abi.encode(1 * 1e18, mmc)); // assign my content custody to distributor
        require(custodian.isPolicyAuthorized(subscriptionPolicy, msg.sender) == true);
        vm.stopBroadcast();
    }
}
