// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { IRightsPolicyAuthorizer } from "@synaps3/core/interfaces/rights/IRightsPolicyAuthorizer.sol";
import { IPolicyAuditorVerifiable } from "@synaps3/core/interfaces/policies/IPolicyAuditorVerifiable.sol";
import { IPolicy } from "@synaps3/core/interfaces/policies/IPolicy.sol";
import { ArrayOps } from "@synaps3/core/libraries/ArrayOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title RightsPolicyAuthorizer
/// @notice Manages the authorization of policies related to content access and usage rights.
/// @dev This contract ensures that only audited and verified policies can be authorized,
///      maintaining security and consistency across the protocol.
contract RightsPolicyAuthorizer is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    IRightsPolicyAuthorizer
{
    using LoopOps for uint256;
    using ArrayOps for address[];
    using EnumerableSet for EnumerableSet.AddressSet;

    /// KIM: any initialization here is ephemeral and not included in bytecode..
    /// so the code within a logic contract’s constructor or global declaration
    /// will never be executed in the context of the proxy’s state
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#the-constructor-caveat

    ///Our immutables behave as constants after deployment
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    //slither-disable-next-line naming-convention
    IPolicyAuditorVerifiable public immutable POLICY_AUDIT;

    /// @dev Mapping to store the delegated rights for each policy contract (address)
    mapping(address => EnumerableSet.AddressSet) private _authorizedPolicies;
    /// @notice Emitted when rights are granted to a policy for content.
    /// @param policy The policy contract address granted rights.
    /// @param holder The address of the asset rights holder.
    /// @param data The data used to initialize the policy.
    event RightsGranted(address indexed policy, address indexed holder, bytes data);

    /// @notice Emitted when rights are revoked from a policy for content.
    /// @param policy The policy contract address whose rights are being revoked.
    /// @param holder The address of the asset rights holder.
    event RightsRevoked(address indexed policy, address indexed holder);

    /// @dev Error thrown when a policy has not been audited or approved for operation.
    /// @param policy The address of the unaudited policy.
    error InvalidNotAuditedPolicy(address policy);
    /// @dev Error thrown when there is an issue with the policy setup.
    /// @param reason A string explaining the reason for the invalid policy setup.
    error InvalidPolicyInitialization(string reason);

    /// @dev Error thrown when revoking an authorization fails.
    error RevocationFailed(address holder, address policy);

    /// @dev Modifier that restricts access to only audited and valid policies.
    ///      Ensures that the provided policy address has passed verification
    ///      and auditing before authorization and initialization.
    ///      If the policy is invalid or not audited, the transaction will revert.
    /// @param policy The address of the policy contract to verify.
    /// @notice This modifier is used to enforce that only approved policies can be initialized and authorized.
    modifier onlyAuditedPolicies(address policy) {
        // Only valid and audited policies are allowed to be authorized and initialized.
        if (!_isValidPolicy(policy)) revert InvalidNotAuditedPolicy(policy);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address policyAudit) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // audit contract to validate the approval from mods
        POLICY_AUDIT = IPolicyAuditorVerifiable(policyAudit);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Initializes and authorizes a policy contract for content held by the holder.
    /// @param policy The address of the policy contract to be initialized and authorized.
    /// @param data The data to initialize policy. e.g., prices, timeframes..
    function authorizePolicy(address policy, bytes calldata data) external onlyAuditedPolicies(policy) nonReentrant {
        // type safe low level call to policy, call policy initialization with provided data..
        (bool success, ) = policy.call(abi.encodeCall(IPolicy.setup, (msg.sender, data)));
        if (!success) revert InvalidPolicyInitialization("Error during policy initialization call");
        _authorizedPolicies[msg.sender].add(policy);
        emit RightsGranted(policy, msg.sender, data);
    }

    /// @notice Revokes the delegation of rights to a policy contract.
    /// @param policy The address of the policy contract whose rights delegation is being revoked.
    function revokePolicy(address policy) external {
        // if the policy is not authorized revoke fails
        bool revoked = _authorizedPolicies[msg.sender].remove(policy);
        if (!revoked) revert RevocationFailed(msg.sender, policy);
        emit RightsRevoked(policy, msg.sender);
    }

    /// @dev Verify if the specified policy contract has been delegated the rights by the asset holder.
    /// @param policy The address of the policy contract to check for delegation.
    /// @param holder the asset rights holder to check for delegation.
    function isPolicyAuthorized(address policy, address holder) external view returns (bool) {
        return _authorizedPolicies[holder].contains(policy) && _isValidPolicy(policy);
    }

    /// @notice Retrieves all policies authorized by a specific content holder.
    /// @dev This function returns an array of policy addresses that have been granted rights by the holder,
    ///      filtering out any invalid policies.
    /// @param holder The address of the asset rights holder whose authorized policies are being queried.
    function getAuthorizedPolicies(address holder) external view returns (address[] memory) {
        // https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet-values-struct-EnumerableSet-AddressSet-
        // This operation (.values()) will copy the entire storage to memory, which can be quite expensive.
        // This function is designed to be used primarily as a view accessor, queried without any gas fees.
        // Developers should note that this function has an unbounded cost, and using it as part of a state-changing
        // function may render the function uncallable if the set grows to a point where copying to memory
        // consumes too much gas to fit in a block.
        address[] memory policies = _authorizedPolicies[holder].values();
        address[] memory filtered = new address[](policies.length);
        uint256 policiesLen = policies.length;
        uint256 j = 0; // filtered cursor

        for (uint256 i = 0; i < policiesLen; i = i.uncheckedInc()) {
            if (!_isValidPolicy(policies[i])) continue;
            filtered[j] = policies[i];

            // safe unchecked
            // limited to i increment = max policy length
            j = j.uncheckedInc();
        }

        // Explanation:
        // - The `filtered` array was initially created with the same length as `policies`, meaning
        //   it may contain uninitialized elements (`address(0)`) if some policies were invalid.
        // - The variable `j` represents the number of valid policies that passed the filtering process.
        // - To ensure that the returned array contains only these valid policies and no extra default values,
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

    /// @notice Verifies whether a given policy is valid.
    /// @dev The function ensures that the policy address is not the zero address
    ///      and that the policy has been audited.
    /// @param policy The address of the policy contract to verify.
    function _isValidPolicy(address policy) private view returns (bool) {
        return (policy != address(0) && POLICY_AUDIT.isAudited(policy));
    }
}
