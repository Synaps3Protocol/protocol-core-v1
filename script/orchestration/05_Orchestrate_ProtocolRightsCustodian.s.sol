// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { IRightsAssetCustodian } from "contracts/core/interfaces/rights/IRightsAssetCustodian.sol";

contract OrchestrateRightsCustodian is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address rightsCustodian = vm.envAddress("RIGHT_ASSET_CUSTODIAN");
        address distributor = vm.envAddress("DEFAULT_DISTRIBUTOR_ADDRESS");

        vm.startBroadcast(admin);
        // approve initial distributor
        IRightsAssetCustodian custodian = IRightsAssetCustodian(rightsCustodian);
        custodian.grantCustody(distributor); // assign my content custody to distributor
        require(custodian.isCustodian(msg.sender, distributor) == true);
        vm.stopBroadcast();
    }
}
