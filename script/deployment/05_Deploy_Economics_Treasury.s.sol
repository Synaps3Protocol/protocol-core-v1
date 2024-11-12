// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { Treasury } from "contracts/economics/Treasury.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { C } from "contracts/libraries/Constants.sol";

contract DeployTreasury is DeployBase {
    function getGovPermissions() public pure returns (bytes4[] memory) {
        // tollgate grant access to collectors
        bytes4[] memory treasuryAllowed = new bytes4[](1);
        treasuryAllowed[0] = Treasury.collectFees.selector;
        return treasuryAllowed;
    }

    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address impl = address(new Treasury());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(Treasury.initialize, (accessManager));
        address treasury = deployUUPS(impl, init, "SALT_TREASURY");
        vm.stopBroadcast();
        
        _checkExpectedAddress(treasury, "SALT_TREASURY");
        return treasury;
    }
}
