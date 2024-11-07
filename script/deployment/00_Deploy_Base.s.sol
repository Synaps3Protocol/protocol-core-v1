// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";

contract DeployBase is Script {
    address private accessManager;

    modifier BroadcastedByAdmin() {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(admin);
        _;
        vm.stopBroadcast();
    }

    function setAccessManager(address accessManager_) external {
        accessManager = accessManager_;
    }

    function deployUUPS(
        string memory contractName,
        bytes memory initData,
        bytes memory constructorData
    ) internal returns (address) {
        // Deploy the upgradeable contract
        Options memory options; // struct with default values
        options.constructorData = constructorData;
        options.unsafeSkipAllChecks = true; // vm.envBool("UPGRADE_UNSAFE_CHECK");
        return Upgrades.deployUUPSProxy(contractName, initData, options);
    }

    function deployUUPS(string memory contractName, bytes memory initData) internal returns (address) {
        Options memory options; // struct with default values
        options.unsafeSkipAllChecks = true; // vm.envBool("UPGRADE_UNSAFE_CHECK");
        return Upgrades.deployUUPSProxy(contractName, initData, options);
    }

    function deployAccessManagedUUPS(string memory contractName) internal returns (address) {
        return deployUUPS(contractName, abi.encodeWithSignature("initialize(address)", accessManager));
    }

    function deployAccessManagedUUPS(
        string memory contractName,
        bytes memory constructorData
    ) internal returns (address) {
        return deployUUPS(contractName, abi.encodeWithSignature("initialize(address)", accessManager), constructorData);
    }
}
