// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";
import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract DeployTollgate is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address impl = address(new Tollgate());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(Tollgate.initialize, (accessManager));
        address tollgate = deployUUPS(impl, init, "SALT_TOLLGATE");
        vm.stopBroadcast();

        _checkExpectedAddress(tollgate, "SALT_TOLLGATE");
        _logAddress("TOLLGATE", tollgate);
        return tollgate;
    }
}
