// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { IRightsAccessAgreement } from "contracts/interfaces/rightsmanager/IRightsAccessAgreement.sol";
import { IRightsPolicyManager } from "contracts/interfaces/rightsmanager/IRightsPolicyManager.sol";
import { console } from "forge-std/console.sol";

contract OrchestrateCreateSubscriptionAgreement is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address mmc = vm.envAddress("MMC");
        address rightsPolicyManager = vm.envAddress("RIGHT_POLICY_MANAGER");
        address rightsAgreement = vm.envAddress("RIGHT_ACCESS_AGREEMENT");

        vm.startBroadcast(admin);
        address[] memory parties = new address[](1);
        parties[0] = 0x037f2b49721E34296fBD8F9E7e9cc6D5F9ecE7b4;
        IERC20(mmc).approve(rightsAgreement, 10 * 1e18);
        uint256 proof = IRightsAccessAgreement(rightsAgreement).createAgreement(
            10 * 1e18,
            mmc,
            rightsPolicyManager,
            parties,
            ""
        );

        console.logUint(proof);
        vm.stopBroadcast();
    }
}
