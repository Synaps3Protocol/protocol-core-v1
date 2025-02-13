// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { PolicyAudit } from "contracts/policies/PolicyAudit.sol";

function getModPermissions() pure returns (bytes4[] memory) {
    bytes4[] memory auditorAllowed = new bytes4[](2);
    auditorAllowed[0] = PolicyAudit.approve.selector;
    auditorAllowed[1] = PolicyAudit.reject.selector;
    return auditorAllowed;
}
