// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { DeployBase } from "script/00_Deploy_Base.s.sol";
import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";

contract DeployDistributorReferendum is DeployBase {
    address treasury;
    address feesManager;

    function setTreasuryAddress(address treasury_) external {
        treasury = treasury_;
    }

    function setFeesManagerAddress(address feesManager_) external {
        feesManager = feesManager_;
    }

    function run() external BroadcastedByAdmin returns (address) {
        // Deploy the upgradeable contract
        address _proxyAddress = Upgrades.deployUUPSProxy(
            "DistributorReferendum.sol",
            abi.encodeCall(DistributorReferendum.initialize, (treasury, feesManager))
        );

        return _proxyAddress;
    }
}
