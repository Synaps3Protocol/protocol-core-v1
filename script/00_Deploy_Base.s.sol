// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";

contract DeployBase is Script {
    modifier BroadcastedByAdmin() {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(admin);
        _;
        vm.stopBroadcast();
    }

    function deployUUPS(
        string memory contractName,
        bytes memory initData,
        bytes memory constructorData
    ) internal returns (address) {
        // Deploy the upgradeable contract
        Options memory options; // struct with default values
        options.constructorData = constructorData;
        options.unsafeSkipAllChecks = vm.envBool("UPGRADE_UNSAFE_CHECK");
        return Upgrades.deployUUPSProxy(contractName, initData, options);
    }

     function deployUUPS(
        string memory contractName,
        bytes memory initData
    ) internal returns (address) {
        Options memory options; // struct with default values
        options.unsafeSkipAllChecks = vm.envBool("UPGRADE_UNSAFE_CHECK");
        return Upgrades.deployUUPSProxy(contractName, initData, options);
    }


}
