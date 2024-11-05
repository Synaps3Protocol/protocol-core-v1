// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { ContentReferendum } from "contracts/content/ContentReferendum.sol";

contract DeployContentReferendum is DeployBase {
    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("ContentReferendum.sol");
    }
}
