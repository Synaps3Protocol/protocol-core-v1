// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { Tollgate } from "contracts/economics/Tollgate.sol";

function getGovPermissions() pure returns (bytes4[] memory) {
    // tollgate grant access to governacne
    bytes4[] memory tollgateAllowed = new bytes4[](1);
    tollgateAllowed[0] = Tollgate.setFees.selector;
    return tollgateAllowed;
}
