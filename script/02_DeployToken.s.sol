// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/00_DeployBase.s.sol";
import { MMC } from "contracts/economics/MMC.sol";

contract DeployToken is DeployBase {
    function run() external BroadcastedByAdmin returns (address) {
        MMC token = new MMC(1_000_000_000);
        return address(token);
    }
}
