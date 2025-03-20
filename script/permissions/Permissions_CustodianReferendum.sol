// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { CustodianReferendum } from "contracts/custody/CustodianReferendum.sol";

function getGovPermissions() pure returns (bytes4[] memory) {
    bytes4[] memory custodianReferendumAllowed = new bytes4[](3);
    custodianReferendumAllowed[0] = CustodianReferendum.setExpirationPeriod.selector;
    custodianReferendumAllowed[1] = CustodianReferendum.revoke.selector;
    custodianReferendumAllowed[2] = CustodianReferendum.approve.selector;
    return custodianReferendumAllowed;
}
