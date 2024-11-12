// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { RightsAccessAgreement } from "contracts/rightsmanager/RightsAccessAgreement.sol";

contract DeployRightsAccessAgrement is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address treasury = computeCreate3Address("SALT_TREASURY");
        address tollgate = computeCreate3Address("SALT_TOLLGATE");
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address impl = address(new RightsAccessAgreement(treasury, tollgate));
        bytes memory init = abi.encodeCall(RightsAccessAgreement.initialize, (accessManager));
        address agreement = deployUUPS(impl, init, "SALT_RIGHT_ACCESS_AGREEMENT");
        vm.stopBroadcast();

        _checkExpectedAddress(agreement, "SALT_RIGHT_ACCESS_AGREEMENT");
        return agreement;
    }
}
