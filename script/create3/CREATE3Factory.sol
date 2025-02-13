// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { CREATE3 } from "solady/utils/CREATE3.sol";
import { ICREATE3Factory } from "script/create3/ICREATE3Factory.sol";

/// @title Factory for deploying contracts to deterministic addresses via CREATE3.
contract CREATE3Factory is ICREATE3Factory {
    /// @inheritdoc	ICREATE3Factory
    function deploy(bytes32 salt, bytes memory creationCode) external override returns (address deployed) {
        // hash salt with the deployer address to give each deployer its own namespace
        return CREATE3.deployDeterministic(creationCode, salt);
    }

    /// @inheritdoc	ICREATE3Factory
    function getDeployed(bytes32 salt) external view override returns (address deployed) {
        // hash salt with the deployer address to give each deployer its own namespace
        return CREATE3.predictDeterministicAddress(salt);
    }
}
