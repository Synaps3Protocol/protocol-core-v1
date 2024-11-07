// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { EAS } from "contracts/policies/attestation/Eas.sol";
import { SubscriptionPolicy } from "contracts/policies/access/SubscriptionPolicy.sol";
import { IPolicyAuditor } from "contracts/interfaces/policies/IPolicyAuditor.sol";
import { IAttestationProvider } from "contracts/interfaces/IAttestationProvider.sol";

contract OrchestrateProtocolHydration is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address easAddress = vm.envAddress("EAS_ADDRESS");
        address rmaAddress = vm.envAddress("RIGHT_ACCESS_AGREEMENT");
        address contentOwnership = vm.envAddress("CONTENT_OWNERSHIP");
        address policyAuditor = vm.envAddress("POLICY_AUDIT");
        bytes32 easSchemaId = vm.envBytes32("EAS_SCHEMA_ID");

        vm.startBroadcast(admin);
        // seteup eas as attestation provider
        EAS attestationProvider = new EAS(easAddress, easSchemaId);
        address attestationProviderAddress = address(attestationProvider);

        // set initial policies
        SubscriptionPolicy subscriptionPolicy = new SubscriptionPolicy(
            rmaAddress,
            contentOwnership,
            attestationProviderAddress
        );

        // approve initial policies
        IPolicyAuditor registrar = IPolicyAuditor(policyAuditor);
        registrar.submit(address(subscriptionPolicy));
        registrar.approve(address(subscriptionPolicy));

        IAttestationProvider provider = IAttestationProvider(attestationProviderAddress);
        require(registrar.isAudited(address(subscriptionPolicy)), "Invalid inactive policy");
        require(provider.getAddress() == easAddress, "Invalid attestation provider address");

        bytes32 gotAttestationProvidername = keccak256(abi.encodePacked(provider.getName()));
        bytes32 expectedAttestationProviderName = keccak256(abi.encodePacked("EthereumAttestationService"));
        require(gotAttestationProvidername == expectedAttestationProviderName, "Invalid attestation provider name");

        vm.stopBroadcast();
    }
}
