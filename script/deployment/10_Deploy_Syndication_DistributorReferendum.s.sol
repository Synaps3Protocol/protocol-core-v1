// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";
import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract DeployDistributorReferendum is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address treasury = computeCreate3Address("SALT_TREASURY");
        address tollgate = computeCreate3Address("SALT_TOLLGATE");
        address vault = computeCreate3Address("SALT_LEDGER_VAULT");
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address impl = address(new DistributorReferendum(treasury, tollgate, vault));
        bytes memory init = abi.encodeCall(DistributorReferendum.initialize, (accessManager));
        address referendum = deployUUPS(impl, init, "SALT_DISTRIBUTION_REFERENDUM");
        vm.stopBroadcast();

        _checkExpectedAddress(referendum, "SALT_DISTRIBUTION_REFERENDUM");
        _logAddress("DISTRIBUTION_REFERENDUM", referendum);
        return referendum;
    }
}
