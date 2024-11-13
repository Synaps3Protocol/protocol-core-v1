// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { RightsAssetCustodian } from "contracts/rightsmanager/RightsAssetCustodian.sol";

contract DeployRightsAssetCustodian is DeployBase {
    function run() external returns (address) {

        vm.startBroadcast(getAdminPK());
        address accessManager = computeCreate3Address("SALT_ACCESS_MANAGER");
        address distributionReferendum = computeCreate3Address("SALT_DISTRIBUTION_REFERENDUM");
        address impl = address(new RightsAssetCustodian(distributionReferendum));
        bytes memory init = abi.encodeCall(RightsAssetCustodian.initialize, (accessManager));
        address custodian = deployUUPS(impl, init, "SALT_RIGHT_ASSET_CUSTODIAN");
        vm.stopBroadcast();
        
        _checkExpectedAddress(custodian, "SALT_RIGHT_ASSET_CUSTODIAN");
        _logAddress("RIGHT_ASSET_CUSTODIAN", custodian);
        return custodian;
    }
}
