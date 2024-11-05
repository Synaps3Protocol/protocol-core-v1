// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AccessManager } from "contracts/access/AccessManager.sol";

contract DeployAccessManager is DeployBase {
    function run() external BroadcastedByAdmin returns (address) {
        return deployUUPS("AccessManager.sol", abi.encodeCall(AccessManager.initialize, ()));
    }
}
