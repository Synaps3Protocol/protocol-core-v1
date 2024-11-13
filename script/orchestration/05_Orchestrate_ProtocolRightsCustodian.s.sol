// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { IRightsContentCustodian } from "contracts/interfaces/rightsmanager/IRightsContentCustodian.sol";

contract OrchestrateRightsCustodian is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address rightsCustodian = vm.envAddress("RIGHT_CONTENT_CUSTODIAN");
        address distributor = vm.envAddress("DEFAULT_DISTRIBUTOR_ADDRESS");

        vm.startBroadcast(admin);
        // approve initial distributor
        IRightsContentCustodian custodian = IRightsContentCustodian(rightsCustodian);
        custodian.grantCustody(distributor); // assign my content custody to distributor
        require(custodian.isCustodian(msg.sender, distributor) == true);
        vm.stopBroadcast();
    }
}
