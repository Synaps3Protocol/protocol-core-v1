// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ICustodianFactory } from "@synaps3/core/interfaces/custody/ICustodianFactory.sol";

// Each custodian has their own contract. The problem with this approach is that each contract
// has its own implementation. If in the future we need to improve the custodian contract,
// we can't deploy and upgrade each contract individually to update the implementation.
// Even worse, if the contract is not upgradeable, the implementation cannot be updated,
// requiring a new deployment, which is a significant hassle.

// The solution involves using a beacon proxy pattern:
// beaconProxy -> beacon
//             -> beacon
//             -> beacon -> implementation
//             -> beacon
//             -> beacon

/// @title CustodianFactory.
/// @notice Use this contract to create new custodian.
contract CustodianFactory is UpgradeableBeacon, ICustodianFactory {
    /// @notice Mapping to keep track of registered custodian endpoints.
    /// @dev The key is a hashed endpoint string, and the value is the address of the custodian contract.
    ///      This ensures that each endpoint is uniquely assigned to a custodian.
    mapping(bytes32 => address) private _registry;

    /// @notice Mapping that associates a custodian contract with its creator (manager).
    /// @dev Stores the address of the entity that deployed a given custodian.
    mapping(address => address) private _manager;

    /// @notice Event emitted when a new custodian is created.
    /// @param custodianAddress Address of the newly created custodian.
    /// @param endpoint Endpoint associated with the new custodian.
    /// @param endpointHash Endpoint bytes32 hash associate with the new custodian.
    event CustodianCreated(address indexed custodianAddress, string indexed endpoint, bytes32 endpointHash);

    /// @notice Error to be thrown when attempting to register an already registered custodian.
    error CustodianAlreadyRegistered();

    /// @notice Initializes the contract with an implementation contract and sets the initial owner.
    /// @param implementation The address of the implementation contract that custodians will use.
    constructor(address implementation) UpgradeableBeacon(implementation, msg.sender) {}

    /// @notice Retrieves the creator of a given custodian contract.
    /// @param custodian The address of the custodian contract.
    /// @return The address of the entity that created the custodian.
    function getCreator(address custodian) external view returns (address) {
        return _manager[custodian];
    }

    /// @notice Checks whether a given custodian contract has been registered.
    /// @dev A custodian is considered registered if its address is mapped to a creator in the `_manager` mapping.
    /// @param custodian The address of the custodian contract to check.
    /// @return True if the custodian is registered; false otherwise.
    function isRegistered(address custodian) external view returns (bool) {
        return _manager[custodian] != address(0);
    }

    // TODO endpoint expected as multi-address
    // potential validation needed here

    /// @notice Function to create a new custodian contract.
    /// @dev Ensures that the same endpoint is not registered twice.
    /// @param endpoint The endpoint associated with the new custodian.
    /// @return The address of the newly created custodian contract.
    function create(string calldata endpoint) external returns (address) {
        bytes32 endpointHash = _registerEndpoint(endpoint);
        address newContract = _deployCustodian(endpoint);
        _registerManager(newContract, msg.sender);
        // Emit event to log custodian creation.
        emit CustodianCreated(newContract, endpoint, endpointHash);
        return newContract;
    }

    /// @dev Registers the endpoint by hashing it and ensuring it is not already taken.
    /// @param endpoint The endpoint to register.
    /// @return The hashed endpoint.
    function _registerEndpoint(string calldata endpoint) private returns (bytes32) {
        bytes32 hashed = keccak256(abi.encodePacked(endpoint));
        if (_registry[hashed] != address(0)) revert CustodianAlreadyRegistered();
        _registry[hashed] = msg.sender;
        return hashed;
    }

    /// @dev Deploys a new custodian contract using the beacon proxy pattern.
    /// @param endpoint The endpoint associated with the new custodian.
    /// @return The address of the newly created custodian contract.
    function _deployCustodian(string calldata endpoint) private returns (address) {
        bytes memory data = abi.encodeWithSignature("initialize(string,address)", endpoint, msg.sender);
        return address(new BeaconProxy(address(this), data));
    }

    /// @dev Registers the creator of a custodian contract.
    /// @param custodian The address of the custodian contract.
    /// @param creator The address of the entity that created the custodian.
    function _registerManager(address custodian, address creator) private {
        _manager[custodian] = creator;
    }
}
