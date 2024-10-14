// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/00_Deploy_Base.s.sol";
import { DistributorImpl } from "contracts/syndication/DistributorImpl.sol";
import { DistributorFactory } from "contracts/syndication/DistributorFactory.sol";

contract DeployDistributor is DeployBase {
    string endpoint;

    function setEndpoint(string memory endpoint_) external {
        endpoint = endpoint_;
    }

    function run() external BroadcastedByAdmin returns (address) {
        DistributorImpl imp = new DistributorImpl(); //implementation
        // factory implementing an upgradeable beacon that produces beacon proxies..
        DistributorFactory beacon = new DistributorFactory(address(imp));
        return beacon.create(endpoint);
    }
}
