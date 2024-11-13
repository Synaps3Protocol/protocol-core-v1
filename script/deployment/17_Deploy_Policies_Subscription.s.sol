// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { SubscriptionPolicy } from "contracts/policies/access/SubscriptionPolicy.sol";

contract DeploySubscriptionPolicy is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());

        address rightsPolicyManager = computeCreate3Address("SALT_RIGHT_POLICY_MANAGER");
        address AssetOwnership = computeCreate3Address("SALT_CONTENT_OWNERSHIP");
        address easAddress = computeCreate3Address("SALT_ATTESTATION_EAS");

        bytes memory creationCode = type(SubscriptionPolicy).creationCode;
        bytes memory initCode = abi.encodePacked(
            creationCode,
            abi.encode(rightsPolicyManager, AssetOwnership, easAddress)
        );
        
        address policy = deploy(initCode, "SALT_SUBSCRIPTION_POLICY");
        vm.stopBroadcast();

        _checkExpectedAddress(policy, "SALT_SUBSCRIPTION_POLICY");
        _logAddress("SUBSCRIPTION_POLICY", policy);
        return policy;
    }
}
