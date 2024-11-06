// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";

contract DeployTollgate is DeployBase {
    
    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("Tollgate.sol");
    }
}
