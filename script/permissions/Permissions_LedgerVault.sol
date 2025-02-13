// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { LedgerVault } from "contracts/financial/LedgerVault.sol";

function getOpsPermissions() pure returns (bytes4[] memory) {
    bytes4[] memory vaultAllowed = new bytes4[](3);
    vaultAllowed[0] = LedgerVault.lock.selector;
    vaultAllowed[1] = LedgerVault.release.selector;
    vaultAllowed[2] = LedgerVault.claim.selector;
    return vaultAllowed;
}
