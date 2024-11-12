// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import { ContentReferendum } from "contracts/content/ContentReferendum.sol";

function getGovPermissions() pure returns (bytes4[] memory) {
    // contentReferendum grant access to governance
    bytes4[] memory referendumAllowed = new bytes4[](3);
    referendumAllowed[0] = ContentReferendum.revoke.selector;
    referendumAllowed[1] = ContentReferendum.reject.selector;
    referendumAllowed[2] = ContentReferendum.approve.selector;
    return referendumAllowed;
}
