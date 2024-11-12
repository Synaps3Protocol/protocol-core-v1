// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import { PolicyAudit } from "contracts/policies/PolicyAudit.sol";

function getGovPermissions() pure returns (bytes4[] memory) {
    // tollgate grant access to governacne
    // IAccessManager authority = IAccessManager(computeCreate3Address("SALT_ACCESS_MANAGER"));
    // address policyAudit = computeCreate3Address("SALT_POLICY_AUDIT");
    // tollgate grant access to collectors
    bytes4[] memory auditorAllowed = new bytes4[](2);
    auditorAllowed[0] = PolicyAudit.approve.selector;
    auditorAllowed[1] = PolicyAudit.reject.selector;
    return auditorAllowed;
}
