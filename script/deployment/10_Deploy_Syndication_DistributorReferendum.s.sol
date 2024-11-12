// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { C } from "contracts/libraries/Constants.sol";

contract DeployDistributorReferendum is DeployBase {
    function getGovPermissions() public pure returns (bytes4[] memory) {
        bytes4[] memory distributorReferendumAllowed = new bytes4[](3);
        distributorReferendumAllowed[0] = DistributorReferendum.setExpirationPeriod.selector;
        distributorReferendumAllowed[1] = DistributorReferendum.revoke.selector;
        distributorReferendumAllowed[2] = DistributorReferendum.approve.selector;
        return distributorReferendumAllowed;
    }

    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address treasury = computeCreate3Address("SALT_TREASURY");
        address tollgate = computeCreate3Address("SALT_TOLLGATE");
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address impl = address(new DistributorReferendum(treasury, tollgate));
        bytes memory init = abi.encodeCall(DistributorReferendum.initialize, (accessManager));
        address referendum = deployUUPS(impl, init, "SALT_DISTRIBUTION_REFERENDUM");
        vm.stopBroadcast();

        _checkExpectedAddress(referendum, "SALT_DISTRIBUTION_REFERENDUM");
        return referendum;
    }
}
