// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { HookRegistry} from "contracts/lifecycle/HookRegistry.sol";

function getModPermissions() pure returns (bytes4[] memory) {
    bytes4[] memory auditorAllowed = new bytes4[](2);
    auditorAllowed[0] = HookRegistry.submit.selector;
    auditorAllowed[1] = HookRegistry.approve.selector;
    auditorAllowed[2] = HookRegistry.reject.selector;
    return auditorAllowed;
}
