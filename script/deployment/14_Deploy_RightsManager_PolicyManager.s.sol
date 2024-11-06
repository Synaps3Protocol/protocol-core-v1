// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";

contract DeployRightsPolicyManager is DeployBase {

    address rightsAgreement;
    address rightsAuthorizer;

    function setRightsAgreementAddress(address treasury_) external {
        rightsAgreement = treasury_;
    }

    function setRightsAuthorizerAddress(address tollgate_) external {
        rightsAuthorizer = tollgate_;
    }

    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("RightsPolicyManager.sol", abi.encode(rightsAgreement, rightsAuthorizer));
    }
}
