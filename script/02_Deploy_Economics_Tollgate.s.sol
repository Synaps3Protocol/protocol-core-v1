// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { DeployBase } from "script/00_Deploy_Base.s.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";

contract DeployTollgate is DeployBase {
    function run(bool unsafe) external BroadcastedByAdmin returns (address) {
        Options memory options;
        options.unsafeSkipAllChecks = unsafe;

        return Upgrades.deployUUPSProxy("Tollgate.sol", abi.encodeCall(Tollgate.initialize, ()), options);
    }
}
