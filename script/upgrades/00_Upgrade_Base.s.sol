// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CREATE3Factory, ICREATE3Factory } from "script/create3/CREATE3Factory.sol";

abstract contract UpgradeBase is Script {
    function getAdminPK() public view returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }

    function upgradeAndCallUUPS(address proxy, address implementation, bytes memory initData) public returns (address) {
        require(proxy != address(0));
        require(implementation != address(0));
        require(implementation.code.length > 0);
        //!IMPORTANT: This is not a safe upgrade, take any caution or 2-check needed before run this method
        // UUPS proxy upgrade logic is directly available in the implementation, handled by proxy..
        (bool success, ) = proxy.call(abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (implementation, initData)));
        require(success, "Error upgrading contract");
        return proxy;
    }

}
