// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";

function getGovPermissions() pure returns (bytes4[] memory) {
    bytes4[] memory distributorReferendumAllowed = new bytes4[](3);
    distributorReferendumAllowed[0] = DistributorReferendum.setExpirationPeriod.selector;
    distributorReferendumAllowed[1] = DistributorReferendum.revoke.selector;
    distributorReferendumAllowed[2] = DistributorReferendum.approve.selector;
    return distributorReferendumAllowed;
}
