// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";

contract DeployPolicyAudit is DeployBase {
    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("PolicyAudit.sol");
    }
}
