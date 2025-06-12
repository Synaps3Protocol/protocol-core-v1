// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { ICustodianVerifiable } from "@synaps3/core/interfaces/custody/ICustodianVerifiable.sol";
import { IBalanceVerifiable } from "@synaps3/core/interfaces/base/IBalanceVerifiable.sol";
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
    using Math for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// Our immutables behave as constants after deployment
    //slither-disable-next-line naming-convention
    ICustodianVerifiable public immutable CUSTODIAN_REFERENDUM;

    /// @dev the max allowed amount of custodians per holder.
    uint256 private _maxRedundancy;
    /// @dev Tracks which custodians are assigned to each rights holder.
    mapping(address => EnumerableSet.AddressSet) private _custodians;
    /// @dev Number of rights holders currently assigned to each custodian.
    mapping(address => uint256) private _demand; // demand
    /// @dev Priority set by each holder to their assigned custodians. Default is 1.
    mapping(bytes32 => uint256) private _priority;

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

    /// @notice Emitted when a priority is set or updated for a custodian by a rights holder.
    /// @param holder The address of the rights holder.
    /// @param custodian The address of the custodian whose priority was updated.
    /// @param priority The new priority value set by the holder.
    event PrioritySet(address indexed holder, address indexed custodian, uint256 priority);

    /// @dev Error that is thrown when a content hash is already registered.
    error InvalidInactiveCustodian();

    /// @dev Error that is thrown when a new granted custodian exceed the max redundancy.
    error MaxRedundancyAllowedReached();

    /// @dev Error when failing to grant custody to a custodian.
    error GrantCustodyFailed(address custodian, address holder);

    /// @dev Error when failing to revoke custody from a custodian.
    error RevokeCustodyFailed(address custodian, address holder);

    /// @dev Error thrown when an invalid priority value is provided.
    /// @param priority The invalid priority value provided.
    error InvalidPriority(uint256 priority);

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
        // the number of assigned custodians by the holder
        uint256 currentRedundancy = _custodians[msg.sender].length();
        if (currentRedundancy >= _maxRedundancy) {
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
        _maxRedundancy = 3; // redundancy factor (RF)
    }

    /// @notice Updates the maximum allowed number of custodians per holder.
    /// @dev This function allows to dynamically adjust the redundancy limit,
    ///      providing flexibility based on network conditions.
    /// @param value The new maximum number of custodians allowed per holder.
    function setMaxAllowedRedundancy(uint256 value) external restricted {
        _maxRedundancy = value;
    }

    /// @notice Returns the maximum allowed number of custodians per holder.
    function getMaxAllowedRedundancy() external view returns (uint256) {
        return _maxRedundancy;
    }

    /// @notice Revokes custodial rights of a custodian for the caller's assets.
    /// @param custodian The custodian to revoke custody from.
    function revokeCustody(address custodian) external {
        // remove custody from the storage && if does not exist nor granted will revoke
        bool removedCustodian = _custodians[msg.sender].remove(custodian);
        if (!removedCustodian) revert RevokeCustodyFailed(custodian, msg.sender);

        _setPriority(msg.sender, custodian, 0); // reset
        uint256 demand = _decrementCustody(custodian); // -1 under custody
        emit CustodialRevoked(custodian, msg.sender, demand);
    }

    /// @notice Assigns custodial rights over the caller's content to a specified custodian.
    /// @dev Requires the custodian to be active and within redundancy limits.
    ///      Default priority is set to 1 unless explicitly updated by the holder.
    /// @param custodian The address of the custodian to assign.
    function grantCustody(address custodian) external onlyAvailableRedundancy onlyActiveCustodian(custodian) {
        // add custodian to the storage && if already exists the grant will revoke
        // TODO rolling window to keep a list of all the custodians eg: 10 +
        // TODO using the maxAvailable we could limit the number of balanced custodians eg: 5
        // to allow add more redundancy like "backup" but under max control to handle balanced
        // window=[max=[0...5]...10]... later [max=[0...6]...10] <- expanded max to 6
        bool addedCustodian = _custodians[msg.sender].add(custodian);
        if (!addedCustodian) revert GrantCustodyFailed(custodian, msg.sender);

        // TODO a "sybil attack" can create fake reputation around a custodian, charge fees here?..
        _setPriority(msg.sender, custodian, 1); // default: 1
        uint256 demand = _incrementCustody(custodian); // +1 demand
        emit CustodialGranted(custodian, msg.sender, demand);
    }

    /// @notice Returns the weight calculation for a custodian based on holder-defined priority, demand, and balance.
    /// @dev Returns the result of _calcWeight, useful for external observers or audits.
    /// @param custodian The address of the custodian.
    /// @param holder The address of the rights holder.
    /// @param currency The token used for economic evaluation.
    /// @return The calculated weight for this custodian-holder-currency combination.
    function calcWeight(address custodian, address holder, address currency) external view returns (uint256) {
        return _calcWeight(custodian, holder, currency);
    }

    /// @notice Sets a custom priority score for a specific custodian.
    /// @param custodian The target custodian.
    /// @param priority A user-defined priority factor, must be >= 1.
    function setPriority(address custodian, uint256 priority) external {
        _setPriority(msg.sender, custodian, priority);
    }

    /// @notice Checks if the given custodian is a custodian for the specified content holder
    /// @param holder The address of the asset holder.
    /// @param custodian The address of the custodian to check.
    function isCustodian(address custodian, address holder) external view returns (bool) {
        return _custodians[holder].contains(custodian) && _isValidActiveCustodian(custodian);
    }

    /// @notice Retrieves the total number of holders in custody for a given custodian.
    /// @param custodian The address of the custodian whose custodial content count is being requested.
    function getCustodyCount(address custodian) external view returns (uint256) {
        return _demand[custodian];
    }

    /// @notice Selects a custodian for the given holder using weighted randomness.
    /// @dev Balancing is based on priority, demand, and economic backing (balance).
    ///      Not cryptographically secure randomness; avoid for critical paths.
    /// @param holder Address of the rights holder.
    /// @param currency Token used for economic weight evaluation.
    /// @return chosen The address of the selected custodian.
    function getBalancedCustodian(address holder, address currency) external view returns (address chosen) {
        address[] memory custodians = _getCustodians(holder);
        if (custodians.length == 0) return chosen; // TODO fallback custodian

        // Adjust 'n' to comply with the maximum distribution redundancy:
        // This ensures that no more redundancy than allowed is used,
        // even if more custodians are available.
        uint256 n = _maxRedundancy < custodians.length ? _maxRedundancy : custodians.length;
        (uint256[] memory weights, uint256 totalWeight) = _calcWeights(custodians, holder, currency, n);
        /// IMPORTANT: The randomness used here is not cryptographically secure,
        /// but sufficient for this non-critical operation. The random number is generated
        /// using the block hash, currency and the holder's address,
        //  and is used to determine which custodian is selected.
        // slither-disable-next-line weak-prng
        bytes32 blockHash = blockhash(block.number - 1);
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(blockHash, holder, currency)));
        uint256 random = randomSeed % totalWeight;

        uint256 i = 0;
        uint256 acc = 0;

        // factors:
        // p = priority (given by creator)
        // d = demand (merit)
        // b = balance in custodian contract (economic)
        // formula p * (d + 1) * (log2(b) + 1)

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

    // TODO in case of need a custodian during a unexpected failure and the custodian doesnt set the maintance mode
    // we can use this method to get an "emergency" custodian fallback
    // function fallbackCustodian(){}

    /// @notice Retrieves the addresses of the active custodians assigned to a specific content holder.
    /// @param holder The address of the asset holder whose custodians are being retrieved.
    function _getCustodians(address holder) private view returns (address[] memory) {
        address[] memory custodians = _custodians[holder].values();
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

    /// @dev Increases the count of holders served by the custodian.
    /// @param custodian The custodian to increment.
    /// @return The new demand value for this custodian.
    function _incrementCustody(address custodian) private returns (uint256) {
        _demand[custodian] += 1;
        return _demand[custodian];
    }

    /// @dev Decreases the count of holders served by the custodian.
    /// @param custodian The custodian to decrement.
    /// @return The new demand value after the update.
    function _decrementCustody(address custodian) private returns (uint256) {
        if (_demand[custodian] > 0) {
            _demand[custodian] -= 1;
        }

        return _demand[custodian];
    }

    /// @dev Sets or updates the priority for a custodian assigned to a holder.
    ///      Used to influence selection in the balancing logic.
    /// @param custodian The address of the custodian.
    /// @param holder The address of the rights holder.
    /// @param priority The priority value (minimum 1).
    function _setPriority(address custodian, address holder, uint256 priority) private {
        if (priority == 0) revert InvalidPriority(priority);
        _priority[_computeComposedKey(holder, custodian)] = priority;
        emit PrioritySet(msg.sender, custodian, priority);
    }

    /// @dev Computes the weight of a custodian using the formula:
    ///      p · (d + 1) · (log2(b) + 1)
    ///      where:
    ///        - p: priority set by holder
    ///        - d: current demand (number of holders)
    ///        - b: custodian's balance in given currency
    /// @param custodian Address of the custodian to evaluate.
    /// @param holder The holder requesting balance.
    /// @param currency The currency used to query economic strength.
    /// @return Effective weight of the custodian.
    function _calcWeight(address custodian, address holder, address currency) private view returns (uint256) {
        uint256 b = IBalanceVerifiable(custodian).getBalance(currency);
        uint256 p = _priority[_computeComposedKey(holder, custodian)];
        uint256 d = _demand[custodian];
        // wi = pi · (di + 1) · (log2(bi) + 1)
        return p * (d + 1) * (b.log2() + 1);
    }

    /// @dev Calculates weights for each custodian in a selection window using priority, demand, and balance.
    /// @param custodians List of candidate custodians.
    /// @param currency Currency used to evaluate balances.
    /// @param holder The address of the asset holder.
    /// @param window The maximum number of custodians to consider.
    /// @return weights Array of calculated weights.
    /// @return totalWeight Sum of all weights, used for probabilistic selection.
    function _calcWeights(
        address[] memory custodians,
        address currency,
        address holder,
        uint256 window
    ) private view returns (uint256[] memory weights, uint256 totalWeight) {
        weights = new uint256[](window);

        for (uint256 i = 0; i < window; i = i.uncheckedInc()) {
            uint256 w = _calcWeight(custodians[i], holder, currency);
            // safe limited to window
            unchecked {
                totalWeight += w;
                weights[i] = w;
            }
        }
    }

    /// @notice Checks if the custodian is valid and currently active.
    /// @param custodian The address of the custodian to validate.
    /// @return A boolean indicating whether the custodian is valid and active.
    function _isValidActiveCustodian(address custodian) private view returns (bool) {
        return custodian != address(0) && CUSTODIAN_REFERENDUM.isActive(custodian);
    }

    /// @dev Computes a unique key for the (holder, custodian) pair to index priority mappings.
    /// @param holder The address of the rights holder.
    /// @param custodian The address of the custodian.
    /// @return A bytes32 hash uniquely representing the (holder, custodian) relationship.
    function _computeComposedKey(address holder, address custodian) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, custodian));
    }
}
