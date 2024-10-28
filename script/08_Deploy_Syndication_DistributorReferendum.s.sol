// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";
import { DeployBase } from "script/00_Deploy_Base.s.sol";

contract DeployDistributorReferendum is DeployBase {
    address treasury;
    address tollgate;

    function setTreasuryAddress(address treasury_) external {
        treasury = treasury_;
    }

    function setTollgateAddress(address tollgate_) external {
        tollgate = tollgate_;
    }

    function run() external BroadcastedByAdmin returns (address) {
        return
            deployUUPS(
                "DistributorReferendum.sol",
                abi.encodeCall(DistributorReferendum.initialize, ()),
                abi.encode(treasury, tollgate)
            );
    }
}
