// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { IDistributorVerifiable } from "contracts/interfaces/syndication/IDistributorVerifiable.sol";
import { IRightsContentCustodian } from "contracts/interfaces/rightsmanager/IRightsContentCustodian.sol";

contract RightsContentCustodian is Initializable, UUPSUpgradeable, GovernableUpgradeable, IRightsContentCustodian {
    using EnumerableSet for EnumerableSet.AddressSet;
    /// Preventing accidental/malicious changes during contract reinitializations.
    IDistributorVerifiable public immutable DISTRIBUTOR_REFERENDUM;

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
    }

    /// @notice Grants custodial rights over the content held by a holder to a distributor.
    /// @dev This function assigns custodial rights for the content held by a specific
    /// account to a designated distributor.
    /// @param distributor The address of the distributor who will receive custodial rights.
    function grantCustody(address distributor) external onlyActiveDistributor(distributor) {
        // msg.sender expected to be the holder declaring his/her content custody..
        // if it's first custody assignment prev = address(0)
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

    /// @notice Retrieves the custodians' addresses for a given content holder.
    /// @param holder The address of the content rights holder whose custodians' addresses are being retrieved.
    function getCustodians(address holder) public view returns (address[] memory) {
        // TODO collect the custody based on demand, round robin?
        // TODO un metodo que haga un check o seleccion del custodio disponible.
        // TODO VRF generation to select the next custodian?
        // TODO if custodians are blocked we need an auxiliar mechanism and return the higher rated distributor
        return custodying[holder].values();
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
