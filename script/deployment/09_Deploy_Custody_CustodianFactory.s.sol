// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { CustodianImpl } from "contracts/custody/CustodianImpl.sol";
import { CustodianFactory } from "contracts/custody/CustodianFactory.sol";

contract DeployCustodianFactory is DeployBase {
    function run() public returns (address) {
        
        vm.startBroadcast(getAdminPK());
        CustodianImpl imp = new CustodianImpl(); // implementation
        bytes memory creationCode = type(CustodianFactory).creationCode;
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(address(imp)));
        address factory = deploy(initCode, "SALT_CUSTODIAN_FACTORY");
        vm.stopBroadcast();

        _checkExpectedAddress(factory, "SALT_CUSTODIAN_FACTORY");
        _logAddress("CUSTODIAN_FACTORY", factory);
        return factory;
    }
}
