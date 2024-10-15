// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/00_Deploy_Base.s.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";

contract DeployTollgate is DeployBase {

    function run() external BroadcastedByAdmin returns (address) {
        // Deploy the upgradeable contract
        address _proxyAddress = Upgrades.deployUUPSProxy(
            "Tollgate.sol",
            abi.encodeCall(Tollgate.initialize, ())
        );

        return _proxyAddress;
    }
}