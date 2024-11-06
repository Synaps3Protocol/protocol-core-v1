// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";

contract DeployContentVault is DeployBase {
    address contentOwnershipAddress;

    function setContentOwnershipAddress(address contentOwnershipAddress_) external {
        contentOwnershipAddress = contentOwnershipAddress_;
    }

    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("ContentVault.sol", abi.encode(contentOwnershipAddress));
    }
}
