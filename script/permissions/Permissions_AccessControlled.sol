// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { AccessControlledUpgradeable } from "contracts/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { AssetRegistry } from "contracts/assets/AssetRegistry.sol";

function getPauserPermissions() pure returns (bytes4[] memory) {
    // AssetReferendum grant access to governance
    bytes4[] memory accessControlled = new bytes4[](3);
    accessControlled[0] = AccessControlledUpgradeable.pause.selector;
    accessControlled[0] = AccessControlledUpgradeable.unpause.selector;
    return accessControlled;
}

