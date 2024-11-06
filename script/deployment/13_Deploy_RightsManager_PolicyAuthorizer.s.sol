// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";

contract DeployRightsPolicyAuthorizer is DeployBase {
    address policyAudit;

    function setPolicyAudit(address policyAuditAddress) public {
        policyAudit = policyAuditAddress;
    }

    function run() external BroadcastedByAdmin returns (address) {
        return deployAccessManagedUUPS("RightsPolicyAuthorizer.sol", abi.encode(policyAudit));
    }
}
