// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { ContentOwnership } from "contracts/content/ContentOwnership.sol";

contract DeployContentOwnership is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address contentReferendum = computeCreate3Address("SALT_CONTENT_REFERENDUM");
        address impl = address(new ContentOwnership(contentReferendum));
        bytes memory init = abi.encodeCall(ContentOwnership.initialize, (accessManager));
        address contentOwnersip = deployUUPS(impl, init, "SALT_CONTENT_OWNERSHIP");
        vm.stopBroadcast();
        
        _checkExpectedAddress(contentOwnersip, "SALT_CONTENT_OWNERSHIP");
        return contentOwnersip;
    }
}
