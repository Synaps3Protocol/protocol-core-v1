// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import { Treasury } from "contracts/economics/Treasury.sol";

function getGovPermissions() pure returns (bytes4[] memory) {
    // tollgate grant access to collectors
    bytes4[] memory treasuryAllowed = new bytes4[](1);
    treasuryAllowed[0] = Treasury.collectFees.selector;
    return treasuryAllowed;
}
