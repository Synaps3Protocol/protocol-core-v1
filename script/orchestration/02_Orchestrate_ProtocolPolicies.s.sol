// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";
import { IPolicyAuditor } from "contracts/interfaces/policies/IPolicyAuditor.sol";
import { IAttestationProvider } from "contracts/interfaces/IAttestationProvider.sol";

contract OrchestrateProtocolPolicies is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address easAddress = vm.envAddress("EAS_ADDRESS");
        address attestationProviderAddress = vm.envAddress("EAS_ATTESTATION_PROVIDER");
        address subscriptionPolicy = vm.envAddress("SUBSCRIPTION_POLICY");
        address policyAuditor = vm.envAddress("POLICY_AUDIT");

        vm.startBroadcast(admin);
        // approve initial policies
        IPolicyAuditor registrar = IPolicyAuditor(policyAuditor);
        registrar.submit(subscriptionPolicy);
        registrar.approve(subscriptionPolicy);

        IAttestationProvider provider = IAttestationProvider(attestationProviderAddress);
        require(registrar.isAudited(subscriptionPolicy), "Invalid inactive policy");
        require(provider.getAddress() == easAddress, "Invalid attestation provider address");

        bytes32 gotAttestationProvidername = keccak256(abi.encodePacked(provider.getName()));
        bytes32 expectedAttestationProviderName = keccak256(abi.encodePacked("EthereumAttestationService"));
        require(gotAttestationProvidername == expectedAttestationProviderName, "Invalid attestation provider name");

        vm.stopBroadcast();
    }
}
