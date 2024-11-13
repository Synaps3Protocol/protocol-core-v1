// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { IRightsAccessAgreement } from "contracts/interfaces/rightsmanager/IRightsAccessAgreement.sol";
import { IRightsPolicyManager } from "contracts/interfaces/rightsmanager/IRightsPolicyManager.sol";
import {console} from "forge-std/console.sol";

contract OrchestrateRightsAuthorizer is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address rightsPolicyManager = vm.envAddress("RIGHT_POLICY_MANAGER");
        address subscriptionPolicy = vm.envAddress("SUBSCRIPTION_POLICY");

        uint256 proof = vm.parseUint(vm.prompt("add proof"));
        vm.startBroadcast(admin);
        IRightsPolicyManager(rightsPolicyManager).registerPolicy(proof, vm.addr(admin), subscriptionPolicy);
        vm.stopBroadcast();
        
    }
}
