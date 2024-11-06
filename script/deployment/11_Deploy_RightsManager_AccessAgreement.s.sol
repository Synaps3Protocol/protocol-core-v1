// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";

contract DeployRightsAccessAgrement is DeployBase {
    address treasury;
    address tollgate;

    function setTreasuryAddress(address treasury_) external {
        treasury = treasury_;
    }

    function setTollgateAddress(address tollgate_) external {
        tollgate = tollgate_;
    }

    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("RightsAccessAgreement.sol", abi.encode(treasury, tollgate));
    }
}
