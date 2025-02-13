// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { Treasury } from "contracts/economics/Treasury.sol";
import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract DeployTreasury is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new Treasury());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(Treasury.initialize, (accessManager));
        address treasury = deployUUPS(impl, init, "SALT_TREASURY");
        vm.stopBroadcast();

        _checkExpectedAddress(treasury, "SALT_TREASURY");
        _logAddress("TREASURY", treasury);
        return treasury;
    }
}
