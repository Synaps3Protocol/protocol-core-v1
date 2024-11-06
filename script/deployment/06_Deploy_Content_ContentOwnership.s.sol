// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";

contract DeployContentOwnership is DeployBase {
    address contentReferendum;

    function setContentReferendum(address contentReferendum_) external {
        contentReferendum = contentReferendum_;
    }

    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("ContentOwnership.sol", abi.encode(contentReferendum));
    }
}
