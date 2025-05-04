// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { CustodianReferendum } from "contracts/custody/CustodianReferendum.sol";
import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract DeployCustodianReferendum is DeployBase {
    function run() external returns (address) {
        vm.startBroadcast(getAdminPK());
        address tollgate = computeCreate3Address("SALT_TOLLGATE");
        address agreementSettler = computeCreate3Address("SALT_AGREEMENT_SETTLER");
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address impl = address(new CustodianReferendum(tollgate, agreementSettler));
        bytes memory init = abi.encodeCall(CustodianReferendum.initialize, (accessManager));
        address referendum = deployUUPS(impl, init, "SALT_CUSTODIAN_REFERENDUM");
        vm.stopBroadcast();

        _checkExpectedAddress(referendum, "SALT_CUSTODIAN_REFERENDUM");
        _logAddress("CUSTODIAN_REFERENDUM", referendum);
        return referendum;
    }
}
