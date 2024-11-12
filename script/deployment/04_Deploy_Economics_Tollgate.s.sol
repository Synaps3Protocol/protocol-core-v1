// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { C } from "contracts/libraries/Constants.sol";

contract DeployTollgate is DeployBase {
    function getGovPermissions() public pure returns (bytes4[] memory) {
        // tollgate grant access to governacne
        bytes4[] memory tollgateAllowed = new bytes4[](1);
        tollgateAllowed[0] = Tollgate.setFees.selector;
        return tollgateAllowed;
    }

    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address impl = address(new Tollgate());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(Tollgate.initialize, (accessManager));
        address tollgate = deployUUPS(impl, init, "SALT_TOLLGATE");
        vm.stopBroadcast();

        _checkExpectedAddress(tollgate, "SALT_TOLLGATE");
        return tollgate;
    }
}
