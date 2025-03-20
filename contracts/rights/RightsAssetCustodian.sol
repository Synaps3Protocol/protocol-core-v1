// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { ICustodianVerifiable } from "@synaps3/core/interfaces/custody/ICustodianVerifiable.sol";
import { IRightsAssetCustodian } from "@synaps3/core/interfaces/rights/IRightsAssetCustodian.sol";

import { C } from "@synaps3/core/primitives/Constants.sol";

/// @title RightsAssetCustodian
/// @notice Manages the assignment and verification of custodian rights for content holders.
/// @dev This contract ensures that only approved custodians can act as custodians for content holders.
///      It enforces redundancy limits to balance custodian network and uses an approval mechanism
///      to validate the activity status of custodians.
contract RightsAssetCustodian is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IRightsAssetCustodian {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// Our immutables behave as constants after deployment
    //slither-disable-next-line naming-convention
    ICustodianVerifiable public immutable CUSTODIAN_REFERENDUM;

    /// @dev the max allowed amount of custodians per holder.
    uint256 private _maxDistributionRedundancy;
    /// @dev Mapping to store the custodiaN address for each content rights holder.
    mapping(address => EnumerableSet.AddressSet) private _custodiansByHolder;
    /// @dev Mapping to store a registry of rights holders associated with each custodian.
    mapping(address => uint256) private _holdersUnderCustodian;

    /// @notice Emitted when custodian rights are granted to a custodian.
    /// @param newCustody The address of the custodian granted custodial rights.
    /// @param rightsHolder The address of the asset's rights holder.
    event CustodialGranted(address indexed newCustody, address indexed rightsHolder);

    /// @notice Emitted when custodian rights are granted to a custodian.
    /// @param revokedCustody The address of the custodian granted custodial rights.
    /// @param rightsHolder The address of the asset's rights holder.
    event CustodialRevoked(address indexed revokedCustody, address indexed rightsHolder);

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
        if (currentRedundancy >= _maxDistributionRedundancy) {
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
        _maxDistributionRedundancy = 3; // redundancy factor (RF)
    }

    /// @notice Updates the maximum allowed number of custodians per holder.
    /// @dev This function allows to dynamically adjust the redundancy limit,
    ///      providing flexibility based on network conditions.
    /// @param value The new maximum number of custodians allowed per holder.
    function setMaxAllowedRedundancy(uint256 value) external restricted {
        _maxDistributionRedundancy = value;
    }

    /// @notice Revokes custodial rights of a custodian for the caller's assets.
    /// @param custodian The custodian to revoke custody from.
    function revokeCustody(address custodian) external {
        // remove custody from the storage && if does not exist nor granted will revoke
        bool removedCustodian = _custodiansByHolder[msg.sender].remove(custodian);
        if (!removedCustodian) revert RevokeCustodyFailed(custodian, msg.sender);
        _decrementCustody(custodian); // -1 under custody
        emit CustodialRevoked(custodian, msg.sender);
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
        _incrementCustody(custodian); // +1 under custody
        emit CustodialGranted(custodian, msg.sender);
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
    /// acts like a server, and the function balances the requests (custody assignments) based on a weighted
    /// probability distribution. Custodians with higher weights have a greater chance of being selected, much
    /// like how a load balancer directs more traffic to servers with greater capacity.
    /// @param holder The address of the asset rights holder whose custodian is to be selected.
    function getBalancedCustodian(address holder) external view returns (address chosen) {
        uint256 i = 0;
        uint256 acc = 0;
        bytes32 blockHash = blockhash(block.number - 1);
        // This calculation limits the resulting range to 0-9999.
        // Example: a % b => 153_000 % 10_000
        // Step 1: 153_000 / 10_000 = 15.3 (integer part = 15)
        // Step 2: 15 * 10_000 = 150_000
        // Step 3: 153_000 - 150_000 = [3_000]
        // The remainder [3_000] represents the leftover from the division,
        // as the divisor covers the largest possible portion of the dividend
        // with complete multiples, leaving the rest as the remainder.
        // 15 integer parts make up 150_000, while the remaining 3_000 is the residue.

        /// IMPORTANT: The randomness used here is not cryptographically secure,
        /// but sufficient for this non-critical operation. The random number is generated
        /// using the block hash and the holder's address, and is used to determine which custodian is selected.
        // slither-disable-next-line weak-prng
        uint256 random = uint256(keccak256(abi.encodePacked(blockHash, holder))) % C.BPS_MAX;
        uint256 n = _custodiansByHolder[holder].length();
        // Adjust 'n' to comply with the maximum distribution redundancy:
        // This ensures that no more redundancy than allowed is used,
        // even if more custodians are available.
        n = _maxDistributionRedundancy < n ? _maxDistributionRedundancy : n;
        // Arithmetic succession of weights:
        // Example: n = total number of nodes
        // Node 1 = weight 3
        // Node 2 = weight 2
        // Node 3 = weight 1
        // Total weight = 6 (sum of weights in descending order)
        //
        // To calculate the sum of all node weights dynamically:
        // Adding a new node automatically adjusts both the weights and their total sum.
        // Formula for the sum of an arithmetic succession: S = n(n + 1) / 2
        // Example:
        // Before: n = 3 -> 1 + 2 + 3 = 6
        // After:  n = 4 -> 1 + 2 + 3 + 4 = 10
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
            // |          0 - 50          |      51 - 80     |   81 - 100  | <- acc <> random hit range
            // The first node (50%) has the highest chance, followed by the second (30%) and the third (20%).

            // += weight for node i
            // Each node's weight is calculated as a proportion of the total weight (`s`),
            // based on its position (order). The first node has the highest weight, with
            // subsequent nodes receiving progressively smaller weights.
            // Example: First node = weight 3 * 10,000 / total weight (s)
            // This ensures nodes with higher weights (closer to the start) have a greater
            // probability of being selected.
            acc += ((n - i) * C.BPS_MAX) / s;
            address candidate = _custodiansByHolder[holder].at(i);
            if (acc >= random && _isValidActiveCustodian(candidate)) {
                chosen = candidate;
            }

            // i can't overflow n
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Retrieves the addresses of the custodians assigned to a specific content holder.
    /// @dev Is not guaranteed that returned custodians are actives. use `getBalancedCustodian` in place.
    /// @param holder The address of the asset holder whose custodians are being retrieved.
    function getCustodians(address holder) external view returns (address[] memory) {
        return _custodiansByHolder[holder].values();
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

    /// @dev Increments the count of holders under a given custodian's custody.
    /// @param custodian The address of the custodian whose custody count will be incremented.
    function _incrementCustody(address custodian) private {
        _holdersUnderCustodian[custodian] += 1;
    }

    /// @dev Decrements the count of holders under a given custodian's custody.
    /// @param custodian The address of the custodian whose custody count will be decremented.
    function _decrementCustody(address custodian) private {
        if (_holdersUnderCustodian[custodian] > 0) {
            _holdersUnderCustodian[custodian] -= 1;
        }
    }
}
