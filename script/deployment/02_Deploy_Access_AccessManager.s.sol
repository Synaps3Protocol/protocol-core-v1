// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { AccessManager } from "contracts/access/AccessManager.sol";

contract DeployAccessManager is DeployBase {
    function run() external returns (address) {
        uint256 privateKey = getAdminPK();
        address publicKey = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        address impl = address(new AccessManager());
        bytes memory init = abi.encodeCall(AccessManager.initialize, (publicKey));
        address accessManager = deployUUPS(impl, init, "SALT_ACCESS_MANAGER");
        vm.stopBroadcast();

        _checkExpectedAddress(accessManager, "SALT_ACCESS_MANAGER");
        _logAddress("ACCESS_MANAGER", accessManager);
        return accessManager;
    }
}
