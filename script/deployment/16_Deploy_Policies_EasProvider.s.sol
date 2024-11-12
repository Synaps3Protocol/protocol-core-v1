// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { EAS } from "contracts/policies/attestation/Eas.sol";

contract DeployEasProvider is DeployBase {
    function run() external returns (address) {
        
        bytes32 easSchemaId = vm.envBytes32("EAS_SCHEMA_ID");
        address easAddress = vm.envAddress("EAS_ADDRESS");
        
        vm.startBroadcast(getAdminPK());
        bytes memory creationCode = type(EAS).creationCode;
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(easAddress, easSchemaId));
        address provider = deploy(initCode, "SALT_ATTESTATION_EAS");
        vm.stopBroadcast();

        _checkExpectedAddress(provider, "SALT_ATTESTATION_EAS");
        return provider;
    }
}
