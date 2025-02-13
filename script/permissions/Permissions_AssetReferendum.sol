// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { AssetReferendum } from "contracts/assets/AssetReferendum.sol";

function getGovPermissions() pure returns (bytes4[] memory) {
    // AssetReferendum grant access to governance
    bytes4[] memory referendumAllowed = new bytes4[](3);
    referendumAllowed[0] = AssetReferendum.revoke.selector;
    referendumAllowed[1] = AssetReferendum.reject.selector;
    referendumAllowed[2] = AssetReferendum.approve.selector;
    return referendumAllowed;
}

