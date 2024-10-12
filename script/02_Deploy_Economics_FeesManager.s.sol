// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/00_Deploy_Base.s.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { FeesManager } from "contracts/economics/FeesManager.sol";

contract DeployFeesManager is DeployBase {

    function run() external BroadcastedByAdmin returns (address) {
        // Deploy the upgradeable contract
        address _proxyAddress = Upgrades.deployUUPSProxy(
            "FeesManager.sol",
            abi.encodeCall(FeesManager.initialize, ())
        );

        return _proxyAddress;
    }
}
