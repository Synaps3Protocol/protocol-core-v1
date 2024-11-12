// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { ContentVault } from "contracts/content/ContentVault.sol";

contract DeployContentVault is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address contentOwnership = computeCreate3Address("SALT_CONTENT_OWNERSHIP");
        address impl = address(new ContentVault(contentOwnership));
        bytes memory init = abi.encodeCall(ContentVault.initialize, (accessManager));
        address contentVault = deployUUPS(impl, init, "SALT_CONTENT_VAULT");
        vm.stopBroadcast();

        _checkExpectedAddress(contentVault, "SALT_CONTENT_VAULT");
        return contentVault;
    }
}
