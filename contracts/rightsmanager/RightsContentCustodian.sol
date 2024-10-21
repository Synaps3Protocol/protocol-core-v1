// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { IDistributorVerifiable } from "contracts/interfaces/syndication/IDistributorVerifiable.sol";
import { IRightsContentCustodian } from "contracts/interfaces/rightsmanager/IRightsContentCustodian.sol";

import { C } from "contracts/libraries/Constants.sol";

contract RightsContentCustodian is Initializable, UUPSUpgradeable, GovernableUpgradeable, IRightsContentCustodian {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// Preventing accidental/malicious changes during contract reinitializations.
    IDistributorVerifiable public immutable DISTRIBUTOR_REFERENDUM;

    /// @dev the max allowed amount of distributors per holder.
    uint256 private maxDistributionRedundancy;
    /// @dev Mapping to store the custodial address for each content rights holder.
    mapping(address => EnumerableSet.AddressSet) private custodying;
    /// @dev Mapping to store a registry of rights holders associated with each distributor.
    mapping(address => EnumerableSet.AddressSet) private registry;

    /// @notice Emitted when distribution custodial rights are granted to a distributor.
    /// @param newCustody The new distributor custodial address.
    /// @param rightsHolder The content rights holder.
    event CustodialGranted(address indexed newCustody, address indexed rightsHolder);
    /// @dev Error that is thrown when a content hash is already registered.
    error InvalidInactiveDistributor();
    error MaxRedundancyAllowedReached();

    /// @notice Modifier to check if the distributor is active and not blocked.
    /// @param distributor The distributor address to check.
    modifier onlyActiveDistributor(address distributor) {
        if (distributor == address(0) || !DISTRIBUTOR_REFERENDUM.isActive(distributor))
            revert InvalidInactiveDistributor();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address distributorReferendum) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to verify the status of each distributor before allow custodian assigment.
        DISTRIBUTOR_REFERENDUM = IDistributorVerifiable(distributorReferendum);
    }

    /// @notice Initializes the proxy state.
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
        // the max amount of distributors per holder..
        // we can use this attribute to control de "stress" in the network
        // eg: if the network is growing we can adjust this attribute to allow more
        // redundancy and more backend distributors..
        maxDistributionRedundancy = 3;
    }

    /// @notice Grants custodial rights over the content held by a holder to a distributor.
    /// @dev This function assigns custodial rights for the content held by a specific
    /// account to a designated distributor.
    /// @param distributor The address of the distributor who will receive custodial rights.
    function grantCustody(address distributor) external onlyActiveDistributor(distributor) {
        // msg.sender expected to be the holder declaring his/her content custody..
        if (custodying[msg.sender].length() >= maxDistributionRedundancy) {
            revert MaxRedundancyAllowedReached();
        }

        custodying[msg.sender].add(distributor);
        registry[distributor].add(msg.sender);
        emit CustodialGranted(distributor, msg.sender);
    }

    /// @notice Retrieves the total number of content items in custody for a given distributor.
    /// @param distributor The address of the distributor whose custodial content count is being requested.
    function getCustodyCount(address distributor) public view returns (uint256) {
        return registry[distributor].length();
    }

    /// @notice Retrieves the custody records associated with a specific distributor.
    /// @dev This function returns an array of content IDs that the given distributor has in custody.
    /// @param distributor The address of the distributor whose custody records are to be retrieved.
    function getCustodyRegistry(address distributor) public view returns (address[] memory) {
        // https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet-values-struct-EnumerableSet-AddressSet-
        // This operation will copy the entire storage to memory, which can be quite expensive.
        // This function is designed to mostly be used by view accessors that are queried without any gas fees.
        // Developers should keep in mind that this function has an unbounded cost,
        /// and using it as part of a state-changing function may render the function uncallable
        /// if the set grows to a point where copying to memory consumes too much gas to fit in a block.
        return registry[distributor].values();
    }

    /// @notice Selects a balanced custodian for a given content rights holder based on weighted randomness.
    /// @dev This function behaves similarly to a load balancer in a network proxy system, where each custodian
    /// acts like a server, and the function balances the requests (custody assignments) based on a weighted
    /// probability distribution. Custodians with higher weights have a greater chance of being selected, much
    /// like how a load balancer directs more traffic to servers with greater capacity.
    ///
    /// The randomness used here is not cryptographically secure, but sufficient for this non-critical operation.
    /// The random number is generated using the block hash and the sender's address, and is used to determine
    /// which custodian is selected.
    /// @param holder The address of the content rights holder whose custodian is to be selected.
    /// @return choosen The address of the selected custodian.
    function getBalancedCustodian(address holder) public view returns (address choosen) {
        uint256 i = 0;
        uint256 acc = 0;
        bytes32 blockHash = blockhash(block.number - 1);
        uint256 random = uint256(keccak256(abi.encodePacked(blockHash, msg.sender))) % C.BPS_MAX;
        uint256 n = custodying[holder].length();
        // arithmetic sucesion
        // eg: 3 = 1+2+3 =  n(n+1) / 2 = 6
        uint256 s = (n * (n + 1)) / 2;

        while (i < n) {
            // Calculate the weight for each node based on its index (n - i), where the first node gets
            // the highest weight, and the weights decrease as i increases.
            // We multiply by BPS_MAX (usually 10,000 bps = 100%) to ensure precision, and divide by
            // the total weight sum 's' to normalize.
            // Formula: w = ((n - i) * BPS_MAX) / s
            //
            // In a categorical probability distribution, nodes with higher weights have a greater chance
            // of being selected. The random value is checked against the cumulative weight.
            // Example distribution:
            // |------------50------------|--------30--------|-----20------|
            // The first node (50%) has the highest chance, followed by the second (30%) and the third (20%).
            // += weight for node i
            acc += (((n - i) * C.BPS_MAX) / s);

            if (acc >= random) {
                choosen = custodying[holder].at(i);
            }

            // i can't overflow n
            unchecked {
                i++;
            }
        }
    }

    /// @notice Retrieves the custodians' addresses for a given content holder.
    /// @param holder The address of the content rights holder whose custodians' addresses are being retrieved.
    function getCustodians(address holder) public view returns (address[] memory) {
        return custodying[holder].values();
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
