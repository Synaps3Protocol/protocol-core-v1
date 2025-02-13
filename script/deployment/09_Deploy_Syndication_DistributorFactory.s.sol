// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { DistributorImpl } from "contracts/syndication/DistributorImpl.sol";
import { DistributorFactory } from "contracts/syndication/DistributorFactory.sol";

contract DeployDistributorFactory is DeployBase {
    function run() public returns (address) {
        
        vm.startBroadcast(getAdminPK());
        DistributorImpl imp = new DistributorImpl(); // implementation
        bytes memory creationCode = type(DistributorFactory).creationCode;
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(address(imp)));
        address factory = deploy(initCode, "SALT_DISTRIBUTION_FACTORY");
        vm.stopBroadcast();

        _checkExpectedAddress(factory, "SALT_DISTRIBUTION_FACTORY");
        _logAddress("DISTRIBUTION_FACTORY", factory);
        return factory;
    }
}
