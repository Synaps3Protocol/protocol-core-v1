// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/00_Deploy_Base.s.sol";
import { Treasury } from "contracts/economics/Treasury.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployTreasury is DeployBase {
    function run() external BroadcastedByAdmin returns (address) {
        return deployUUPS("Treasury.sol", abi.encodeCall(Treasury.initialize, ()), "");
    }
}
