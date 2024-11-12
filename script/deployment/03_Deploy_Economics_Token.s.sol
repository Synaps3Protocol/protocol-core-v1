// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { MMC } from "contracts/economics/MMC.sol";

contract DeployToken is DeployBase {
    function run() external returns (address) {
        
        uint256 privateKey = getAdminPK();
        address publicKey = vm.addr(privateKey);

        vm.startBroadcast(getAdminPK());
        bytes memory creationCode = type(MMC).creationCode;
        // add constructor args as 1,000,000,000 MMC initial supply
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(publicKey, 1_000_000_000));
        address token = deploy(initCode, "SALT_MMC");
        vm.stopBroadcast();

        _checkExpectedAddress(token, "SALT_MMC");
        return token;
    }
}
