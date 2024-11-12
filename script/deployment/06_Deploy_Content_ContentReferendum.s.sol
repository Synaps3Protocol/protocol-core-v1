// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { ContentReferendum } from "contracts/content/ContentReferendum.sol";

contract DeployContentReferendum is DeployBase {
    function getGovPermissions() public pure returns (bytes4[] memory) {
        // contentReferendum grant access to governance
        bytes4[] memory referendumAllowed = new bytes4[](3);
        referendumAllowed[0] = ContentReferendum.revoke.selector;
        referendumAllowed[1] = ContentReferendum.reject.selector;
        referendumAllowed[2] = ContentReferendum.approve.selector;
        return referendumAllowed;
    }

    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address impl = address(new ContentReferendum());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        bytes memory init = abi.encodeCall(ContentReferendum.initialize, (accessManager));
        address contentReferendum = deployUUPS(impl, init, "SALT_CONTENT_REFERENDUM");
        vm.stopBroadcast();
        
        _checkExpectedAddress(contentReferendum, "SALT_CONTENT_REFERENDUM");
        return contentReferendum;
    }
}
