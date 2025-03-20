// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { IRightsAssetCustodian } from "contracts/core/interfaces/rights/IRightsAssetCustodian.sol";

contract OrchestrateRightsCustodian is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address rightsCustodian = vm.envAddress("RIGHT_ASSET_CUSTODIAN");
        address defaultCustodian = vm.envAddress("DEFAULT_CUSTODIAN_ADDRESS");

        vm.startBroadcast(admin);
        // approve initial custodian
        IRightsAssetCustodian custodian = IRightsAssetCustodian(rightsCustodian);
        custodian.grantCustody(defaultCustodian); // assign my content custody to custodian
        require(custodian.isCustodian(msg.sender, defaultCustodian) == true);
        vm.stopBroadcast();
    }
}
