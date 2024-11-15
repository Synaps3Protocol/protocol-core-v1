// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { IPolicy } from "contracts/core/interfaces/policies/IPolicy.sol";
import { IRightsPolicyAuthorizer } from "contracts/core/interfaces/rightsmanager/IRightsPolicyAuthorizer.sol";
import { T } from "contracts/core/primitives/Types.sol";

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

        // verify policy initialization
        T.Terms memory terms = IPolicy(subscriptionPolicy).resolveTerms(msg.sender);
        require(terms.amount == 1 * 1e18);
        require(terms.currency == mmc);
        require(terms.rateBasis == T.RateBasis.DAILY);
        vm.stopBroadcast();
    }
}
