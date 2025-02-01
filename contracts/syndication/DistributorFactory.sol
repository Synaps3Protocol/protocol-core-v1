// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

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

/// @title DistributorFactory.
/// @notice Use this contract to create new distributors.
/// @dev This contract uses OpenZeppelin's Ownable and Pausable contracts for access control and pausing functionality.
contract DistributorFactory is UpgradeableBeacon, IDistributorFactory {
    /// @notice Mapping to keep track of registered distributor endpoints.
    /// @dev The key is a hashed endpoint string, and the value is the address of the distributor contract.
    ///      This ensures that each endpoint is uniquely assigned to a distributor.
    mapping(bytes32 => address) private _registry;

    /// @notice Mapping that associates a distributor contract with its creator (manager).
    /// @dev Stores the address of the entity that deployed a given distributor.
    mapping(address => address) private _manager;

    /// @notice Event emitted when a new distributor is created.
    /// @param distributorAddress Address of the newly created distributor.
    /// @param endpoint Endpoint associated with the new distributor.
    event DistributorCreated(address indexed distributorAddress, string indexed endpoint, bytes32 endpointHash);

    /// @notice Error to be thrown when attempting to register an already registered distributor.
    error DistributorAlreadyRegistered();

    /// @notice Initializes the contract with an implementation contract and sets the initial owner.
    /// @param implementation The address of the implementation contract that distributors will use.
    constructor(address implementation) UpgradeableBeacon(implementation, msg.sender) {}

    /// @notice Retrieves the creator of a given distributor contract.
    /// @param distributor The address of the distributor contract.
    /// @return The address of the entity that created the distributor.
    function getCreator(address distributor) external view returns (address) {
        return _manager[distributor];
    }

    // TODO: check domain existence

    /// @notice Function to create a new distributor contract.
    /// @dev Ensures that the same endpoint is not registered twice.
    /// @param endpoint The endpoint associated with the new distributor.
    /// @return The address of the newly created distributor contract.
    function create(string calldata endpoint) external returns (address) {
        // TODO additional validation needed to check endpoint schemes. eg: https, ip, etc
        // TODO option two, penalize invalid endpoints, and revoked during referendum
        bytes32 endpointHash = _registerEndpoint(endpoint);
        address newContract = _deployDistributor(endpoint);
        _registerManager(newContract, msg.sender);
        // Emit event to log distributor creation.
        emit DistributorCreated(newContract, endpoint, endpointHash);
        return newContract;
    }

    /// @dev Registers the endpoint by hashing it and ensuring it is not already taken.
    /// @param endpoint The endpoint to register.
    /// @return The hashed endpoint.
    function _registerEndpoint(string calldata endpoint) private returns (bytes32) {
        bytes32 hashed = keccak256(abi.encodePacked(endpoint));
        if (_registry[hashed] != address(0)) revert DistributorAlreadyRegistered();
        _registry[hashed] = msg.sender;
        return hashed;
    }

    /// @dev Deploys a new distributor contract using the beacon proxy pattern.
    /// @param endpoint The endpoint associated with the new distributor.
    /// @return The address of the newly created distributor contract.
    function _deployDistributor(string calldata endpoint) private returns (address) {
        bytes memory data = abi.encodeWithSignature("initialize(string,address)", endpoint, msg.sender);
        return address(new BeaconProxy(address(this), data));
    }

    /// @dev Registers the creator of a distributor contract.
    /// @param distributor The address of the distributor contract.
    /// @param creator The address of the entity that created the distributor.
    function _registerManager(address distributor, address creator) private {
        _manager[distributor] = creator;
    }
}
