// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/00_Deploy_Base.s.sol";
import { ContentReferendum } from "contracts/assets/ContentReferendum.sol";


contract DeployContentReferendum is DeployBase {
    function run() external BroadcastedByAdmin returns (address) {
        return deployUUPS("ContentReferendum.sol", abi.encodeCall(ContentReferendum.initialize, ()));
    }
}
