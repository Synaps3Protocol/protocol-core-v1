// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { ICustodianVerifiable } from "@synaps3/core/interfaces/custody/ICustodianVerifiable.sol";
import { IRightsAssetCustodian } from "@synaps3/core/interfaces/rights/IRightsAssetCustodian.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title RightsAssetCustodian
/// @notice Manages the assignment and verification of custodian rights for content holders.
/// @dev This contract ensures that only approved custodians can act as custodians for content holders.
///      It enforces redundancy limits to balance custodian network and uses an approval mechanism
///      to validate the activity status of custodians.
contract RightsAssetCustodian is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IRightsAssetCustodian {
    using EnumerableSet for EnumerableSet.AddressSet;
    using LoopOps for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// Our immutables behave as constants after deployment
    //slither-disable-next-line naming-convention
    ICustodianVerifiable public immutable CUSTODIAN_REFERENDUM;

    /// @dev the max allowed amount of custodians per holder.
    uint256 private _maxCustodianRedundancy;
    /// @dev Mapping to store the custodiaN address for each content rights holder.
    mapping(address => EnumerableSet.AddressSet) private _custodiansByHolder;
    /// @dev Mapping to store a registry of rights holders associated with each custodian.
    mapping(address => uint256) private _holdersUnderCustodian;

    /// @notice Emitted when custodian rights are granted to a custodian.
    /// @param newCustody The address of the custodian granted custodial rights.
    /// @param rightsHolder The address of the asset's rights holder.
    /// @param demand The total number of holders currently assigned to the custodian (under custody).
    event CustodialGranted(address indexed newCustody, address indexed rightsHolder, uint256 demand);

    /// @notice Emitted when custodian rights are granted to a custodian.
    /// @param revokedCustody The address of the custodian granted custodial rights.
    /// @param rightsHolder The address of the asset's rights holder.
    /// @param demand The total number of holders currently assigned to the custodian (under custody).
    event CustodialRevoked(address indexed revokedCustody, address indexed rightsHolder, uint256 demand);

    /// @dev Error that is thrown when a content hash is already registered.
    error InvalidInactiveCustodian();

    /// @dev Error that is thrown when a new granted custodian exceed the max redundancy.
    error MaxRedundancyAllowedReached();

    /// @dev Error when failing to grant custody to a custodian.
    error GrantCustodyFailed(address custodian, address holder);

    /// @dev Error when failing to revoke custody from a custodian.
    error RevokeCustodyFailed(address custodian, address holder);

    /// @dev Modifier to check if the custodian is active and not blocked.
    /// @param custodian The custodian address to check.
    modifier onlyActiveCustodian(address custodian) {
        if (!_isValidActiveCustodian(custodian)) {
            revert InvalidInactiveCustodian();
        }
        _;
    }

    /// @dev Ensures that the caller does not exceed the maximum redundancy limit for custodians.
    modifier onlyAvailableRedundancy() {
        uint256 currentRedundancy = _custodiansByHolder[msg.sender].length();
        if (currentRedundancy >= _maxCustodianRedundancy) {
            revert MaxRedundancyAllowedReached();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address custodianReferendum) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to verify the status of each custodian before allow custodian assignment.
        CUSTODIAN_REFERENDUM = ICustodianVerifiable(custodianReferendum);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
        // the max amount of custodians per holder..
        // we can use this attribute to control de "stress" in the network
        // eg: if the network is growing we can adjust this attribute to allow more
        // redundancy and more backend custodians..
        _maxCustodianRedundancy = 3; // redundancy factor (RF)
    }

    /// @notice Updates the maximum allowed number of custodians per holder.
    /// @dev This function allows to dynamically adjust the redundancy limit,
    ///      providing flexibility based on network conditions.
    /// @param value The new maximum number of custodians allowed per holder.
    function setMaxAllowedRedundancy(uint256 value) external restricted {
        _maxCustodianRedundancy = value;
    }

    /// @notice Revokes custodial rights of a custodian for the caller's assets.
    /// @param custodian The custodian to revoke custody from.
    function revokeCustody(address custodian) external {
        // remove custody from the storage && if does not exist nor granted will revoke
        bool removedCustodian = _custodiansByHolder[msg.sender].remove(custodian);
        if (!removedCustodian) revert RevokeCustodyFailed(custodian, msg.sender);

        uint256 demand = _decrementCustody(custodian); // -1 under custody
        emit CustodialRevoked(custodian, msg.sender, demand);
    }

    /// @notice Grants custodial rights over the asset held by a holder to a custodian.
    /// @param custodian The address of the custodian who will receive custodial rights.
    function grantCustody(address custodian) external onlyAvailableRedundancy onlyActiveCustodian(custodian) {
        // add custodian to the storage && if already exists the grant will revoke
        // TODO rolling window to keep a list of all the custodians eg: 10 +
        // TODO using the maxAvailable we could limit the number of balanced custodians eg: 5
        // to allow add more redundancy like "backup" but under max control to handle balanced
        // window=[max=[0...5]...10]... later [max=[0...6]...10] <- expanded max to 6
        bool addedCustodian = _custodiansByHolder[msg.sender].add(custodian);
        if (!addedCustodian) revert GrantCustodyFailed(custodian, msg.sender);

        // TODO assoc weight here
        uint256 demand = _incrementCustody(custodian); // +1 under custody its analog to "demand"
        emit CustodialGranted(custodian, msg.sender, demand);
    }

    /// @notice Checks if the given custodian is a custodian for the specified content holder
    /// @param holder The address of the asset holder.
    /// @param custodian The address of the custodian to check.
    function isCustodian(address holder, address custodian) external view returns (bool) {
        return _custodiansByHolder[holder].contains(custodian) && _isValidActiveCustodian(custodian);
    }

    /// @notice Retrieves the total number of holders in custody for a given custodian.
    /// @param custodian The address of the custodian whose custodial content count is being requested.
    function getCustodyCount(address custodian) external view returns (uint256) {
        return _holdersUnderCustodian[custodian];
    }

    /// @notice Selects a balanced custodian for a given content rights holder based on weighted randomness.
    /// @dev This function behaves similarly to a load balancer in a network proxy system, where each custodian
    ///      acts like a server, and the function balances the requests (custody assignments) based on a weighted
    ///      probability distribution. Custodians with higher weights have a greater chance of being selected, much
    ///      like how a load balancer directs more traffic to servers with greater capacity.
    /// @param holder The address of the asset rights holder whose custodian is to be selected.
    function getBalancedCustodian(address holder) external view returns (address chosen) {
        address[] memory custodians = getCustodians(holder);
        if (custodians.length == 0) return chosen; // TODO fallback custodian
        // Adjust 'n' to comply with the maximum distribution redundancy:
        // This ensures that no more redundancy than allowed is used,
        // even if more custodians are available.
        uint256 n = _maxCustodianRedundancy < custodians.length ? _maxCustodianRedundancy : custodians.length;
        (uint256[] memory weights, uint256 totalWeight) = _calcWeights(custodians, n);
        /// IMPORTANT: The randomness used here is not cryptographically secure,
        /// but sufficient for this non-critical operation. The random number is generated
        /// using the block hash and the holder's address, and is used to determine which custodian is selected.
        // slither-disable-next-line weak-prng
        bytes32 blockHash = blockhash(block.number - 1);
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(blockHash, holder)));
        uint256 random = randomSeed % totalWeight;

        uint256 i = 0;
        uint256 acc = 0;

        // TODO el orden de seleccion reemplazarlo por pondersaciones dadas directamente por el creador
        // inicialmente se dan en base al orden, pero pueden ser sobreescritas, si quisiera de esta manera
        // dar preferencia a algun custodio, de lo contrario la demanda establece dinamicamente el balance

        // factors:
        // p = priority (given by creator)
        // d = demand (merit)
        // b = balance in custodian contract (economic)
        // formula p * (d + 1) * (log2(b + 1) + 1)

        while (i < n) {
            // In a categorical probability distribution, nodes with higher weights have a greater chance
            // of being selected. The random value is checked against the cumulative weight.
            // Example distribution:
            // |------------50------------|--------30--------|-----20------|
            // |          0 - 50          |      51 - 80     |   81 - 100  | <- acc <> random hit range
            // The first node (50%) has the highest chance, followed by the second (30%) and the third (20%).
            acc += weights[i];
            if (random < acc) {
                chosen = custodians[i];
                break;
            }

            // i can't overflow n
            unchecked {
                ++i;
            }
        }
    }

    // function fallbackCustodian(){}

    /// @notice Retrieves the addresses of the active custodians assigned to a specific content holder.
    /// @param holder The address of the asset holder whose custodians are being retrieved.
    function getCustodians(address holder) public view returns (address[] memory) {
        address[] memory custodians = _custodiansByHolder[holder].values();
        address[] memory filtered = new address[](custodians.length);
        uint256 custodiansLen = custodians.length;
        uint256 j = 0;

        for (uint256 i; i < custodiansLen; i = i.uncheckedInc()) {
            if (!_isValidActiveCustodian(custodians[i])) continue;
            filtered[j] = custodians[i];

            // safe unchecked
            // limited to i increment = max custodian len
            j = j.uncheckedInc();
        }

        // Explanation:
        // - The `filtered` array was initially created with the same length as `custodians`, meaning
        //   it may contain uninitialized elements (`address(0)`) if some custodians were invalid.
        // - The variable `j` represents the number of valid custodians that passed the filtering process.
        // - To ensure that the returned array contains only these valid custodians and no extra default values,
        //   we call `slice(j)`, which creates a new array of exact length `j` and copies only
        //   the first `j` elements from `filtered`.
        // - This prevents returning an array with trailing `address(0)` values, ensuring data integrity
        //   and reducing unnecessary gas costs when the array is processed elsewhere.
        assembly {
            mstore(filtered, j)
        }

        return filtered;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Checks if the custodian is valid and currently active.
    /// @param custodian The address of the custodian to validate.
    /// @return A boolean indicating whether the custodian is valid and active.
    function _isValidActiveCustodian(address custodian) private view returns (bool) {
        return custodian != address(0) && CUSTODIAN_REFERENDUM.isActive(custodian);
    }

    /// @dev Increases the count of holders served by the custodian.
    /// @param custodian The custodian to increment.
    /// @return The new demand value for this custodian.
    function _incrementCustody(address custodian) private returns (uint256) {
        _holdersUnderCustodian[custodian] += 1;
        return _holdersUnderCustodian[custodian];
    }

    /// @dev Decreases the count of holders served by the custodian.
    /// @param custodian The custodian to decrement.
    /// @return The new demand value after the update.
    function _decrementCustody(address custodian) private returns (uint256) {
        if (_holdersUnderCustodian[custodian] > 0) {
            _holdersUnderCustodian[custodian] -= 1;
        }

        return _holdersUnderCustodian[custodian];
    }

    /// @notice Calculates the effective weights for each custodian in the selection window.
    /// @dev The formula used is: (window - i) * (demand + 1), where:
    ///      - 'window - i' reflects the custodian's positional priority (as selected by the creator),
    ///      - 'demand + 1' reflects its current engagement level (i.e., how many holders trust it).
    ///      This approach increases the probability of selecting custodians who are both
    ///      preferred by the holder and already trusted by more participants, effectively
    ///      reinforcing reputation and operational reliability.
    /// @param custodians The list of candidate custodians (already filtered for activeness).
    /// @param window The number of custodians to consider (typically capped by redundancy factor).
    /// @return weights An array of computed weights for each custodian.
    /// @return totalWeight The sum of all weights, used for normalization or random selection.
    function _calcWeights(
        address[] memory custodians,
        uint256 window
    ) private view returns (uint256[] memory weights, uint256 totalWeight) {
        weights = new uint256[](window);

        for (uint256 i = 0; i < window; i = i.uncheckedInc()) {
            // assign higher weight to earlier positions (creator priority), but adjust for demand.
            uint256 d = _holdersUnderCustodian[custodians[i]];
            // EffectiveWeight_i = (n - i) * (Demand_i + 1)
            // TODO weights[custodian[i]] <- por defecto es 1 hasta que no se establezca port el creador
            // w = 1 * d+1 * log2(balance + 1) + 1
            uint256 w = (window - i) * (d + 1);

            // safe
            // limited to window
            unchecked {
                totalWeight += w;
                weights[i] = w;
            }
        }
    }
}
