// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { CREATE3Factory } from "script/create3/CREATE3Factory.sol";

contract DeployCreate3Factory is DeployBase {
    function run() external returns (address factory) {

        vm.startBroadcast(getAdminPK());
        bytes32 salt = getSalt("SALT_CREATE3_FACTORY");
        bytes memory bytecode = type(CREATE3Factory).creationCode;

        assembly {
            factory := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(extcodesize(factory)) {
                revert(0, 0)
            }
        }
        
        vm.stopBroadcast();
        _logAddress("CREATE3_FACTORY", factory);
        return factory;
    }
}
