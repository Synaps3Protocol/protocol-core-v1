// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";

contract DeployBase is Script {
    modifier BroadcastedByAdmin() {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(admin);
        _;
        vm.stopBroadcast();
    }

}
