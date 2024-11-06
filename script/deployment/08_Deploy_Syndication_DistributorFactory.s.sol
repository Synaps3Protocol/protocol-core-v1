// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { DistributorImpl } from "contracts/syndication/DistributorImpl.sol";
import { DistributorFactory } from "contracts/syndication/DistributorFactory.sol";
import { IDistributorFactory } from "contracts/interfaces/syndication/IDistributorFactory.sol";

contract DeployDistributorFactory is DeployBase {
    string endpoint;

    function setEndpoint(string memory endpoint_) external {
        endpoint = endpoint_;
    }

    function create() public returns (address) {
        IDistributorFactory factory = IDistributorFactory(run());
        return factory.create(endpoint);
    }

    function run() public BroadcastedByAdmin returns (address) {
        DistributorImpl imp = new DistributorImpl(); // implementation
        // factory implementing an upgradeable beacon that produces beacon proxies..
        DistributorFactory beacon = new DistributorFactory(address(imp));
        return address(beacon);
    }
}
