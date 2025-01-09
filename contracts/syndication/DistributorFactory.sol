// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IDistributorFactory } from "@synaps3/core/interfaces/syndication/IDistributorFactory.sol";

// Each distributor has their own contract. The problem with this approach is that each contract
// has its own implementation. If in the future we need to improve the distributor contract,
// we can't deploy and upgrade each contract individually to update the implementation.
// Even worse, if the contract is not upgradeable, the implementation cannot be updated,
// requiring a new deployment, which is a significant hassle.

// The solution involves using a beacon proxy pattern:
// beaconProxy -> beacon
//             -> beacon
//             -> beacon -> implementation
//             -> beacon
//             -> beacon

/// @title Distributor factory contract.
/// @notice Use this contract to create new distributors.
/// @dev This contract uses OpenZeppelin's Ownable and Pausable contracts for access control and pausing functionality.
contract DistributorFactory is UpgradeableBeacon, Pausable, IDistributorFactory {
    /// @notice Mapping to keep track of registered distributor endpoints.
    mapping(bytes32 => address) private _registry;
    /// @notice Event emitted when a new distributor is created.
    /// @param distributorAddress Address of the newly created distributor.
    /// @param endpoint Endpoint associated with the new distributor.
    event DistributorCreated(address indexed distributorAddress, string endpoint);

    /// @notice Error to be thrown when attempting to register an already registered distributor.
    error DistributorAlreadyRegistered();

    // initialize implementation and initial owner
    constructor(address implementation) UpgradeableBeacon(implementation, msg.sender) Pausable() {}

    /// @notice Function to pause the contract, preventing the creation of new distributors.
    /// @dev Can only be called by the owner of the contract.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Function to unpause the contract, allowing the creation of new distributors.
    /// @dev Can only be called by the owner of the contract.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Function to create a new distributor contract.
    /// @dev The contract must not be paused to call this function.
    /// @param endpoint The endpoint associated with the new distributor.
    function create(string calldata endpoint) external whenNotPaused returns (address) {
        // avoid duplicated endpoints
        bytes32 hashed = keccak256(abi.encodePacked(endpoint));
        if (_registry[hashed] != address(0)) revert DistributorAlreadyRegistered();
        // check-effects-interaction..
        _registry[hashed] = msg.sender;

        // initialize storage layout using Distributor contract impl..
        bytes memory data = abi.encodeWithSignature("initialize(string,address)", endpoint, msg.sender);
        address newContract = address(new BeaconProxy(address(this), data));
        emit DistributorCreated(newContract, endpoint);
        return newContract;
    }
}
