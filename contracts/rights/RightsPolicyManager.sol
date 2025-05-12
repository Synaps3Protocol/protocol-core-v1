// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";

import { IPolicy } from "@synaps3/core/interfaces/policies/IPolicy.sol";
import { IAgreementSettler } from "@synaps3/core/interfaces/financial/IAgreementSettler.sol";
import { IRightsPolicyManager } from "@synaps3/core/interfaces/rights/IRightsPolicyManager.sol";

// solhint-disable-next-line max-line-length
import { IRightsPolicyAuthorizerVerifiable } from "@synaps3/core/interfaces/rights/IRightsPolicyAuthorizerVerifiable.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";
import { ArrayOps } from "@synaps3/core/libraries/ArrayOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @title RightsPolicyManager
/// @notice Handles policy enforcement, registration, and verification for content rights.
/// @dev This contract ensures that policies are properly authorized before being enforced.
///      It interacts with the `RightsPolicyAuthorizer` to verify delegation and `AgreementSettler`
///      to manage agreements.
contract RightsPolicyManager is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    IRightsPolicyManager
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using ArrayOps for address[];
    using LoopOps for uint256;

    /// Our immutables behave as constants after deployment
    //slither-disable-start naming-convention
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAgreementSettler public immutable AGREEMENT_SETTLER;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRightsPolicyAuthorizerVerifiable public immutable RIGHTS_AUTHORIZER;
    //slither-disable-end naming-convention

    /// @dev Mapping to store the access control list for each content holder and account.
    mapping(address => EnumerableSet.AddressSet) private _closures;

    /// @notice Emitted when access rights are granted to an account based on a specific policy.
    /// @param account The address of the account to which the policy applies.
    /// @param proof A unique identifier for the agreement between holder and account.
    /// @param attestationId A unique identifier for the attestation that confirms the registration.
    /// @param policy The address of the registered policy governing the access rights.
    event Registered(address indexed account, uint256 indexed proof, uint256 attestationId, address policy);

    /// @dev Error thrown when a policy registration fails.
    /// @param account The address of the account for which the policy registration failed.
    /// @param policy The address of the policy that could not be registered.
    error RegistrationFailed(address account, address policy);

    /// @dev Error thrown when attempting to operate on a policy that has not
    /// been delegated rights for the specified content by the rights holder.
    /// @param policy The address of the policy contract attempting to access rights.
    /// @param holder The address of the asset rights holder who must delegate the policy.
    error RightsNotDelegated(address policy, address holder);

    /// @dev Error thrown when the execution of a policy fails due to an internal issue,
    /// such as incorrect conditions, failed checks, or an execution error.
    /// @param reason A descriptive string explaining the enforcement failure.
    error EnforcementFailed(string reason);

    /// @notice Ensures that the specified policy has been authorized by the asset rights holder.
    /// @dev This modifier checks the `RIGHTS_AUTHORIZER` to verify if `policyAddress`
    /// has the necessary authorization from `holder`. If not, it reverts with `RightsNotDelegated`.
    /// @param holder The address of the rights holder who must have authorized the policy.
    /// @param policy The address of the policy contract attempting to access the rights.
    modifier onlyAuthorizedPolicy(address holder, address policy) {
        bool isPolicyAuthorizedByHolder = RIGHTS_AUTHORIZER.isPolicyAuthorized(policy, holder);
        if (!isPolicyAuthorizedByHolder) revert RightsNotDelegated(policy, holder);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address agreementSettler, address rightsAuthorizer) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        AGREEMENT_SETTLER = IAgreementSettler(agreementSettler);
        RIGHTS_AUTHORIZER = IRightsPolicyAuthorizerVerifiable(rightsAuthorizer);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @dev This function verifies the policy's authorization, executes the agreement and registers the policy.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param holder The rights holder whose authorization is required for accessing the assets.
    /// @param policy The address of the policy contract managing the agreement.
    function registerPolicy(
        uint256 proof,
        address holder,
        address policy
    ) external onlyAuthorizedPolicy(holder, policy) nonReentrant returns (uint256[] memory) {
        // 1- retrieves the agreement and marks it as settled..
        T.Agreement memory agreement = AGREEMENT_SETTLER.settleAgreement(proof, holder);
        bytes memory callData = abi.encodeCall(IPolicy.enforce, (holder, agreement));
        /// Type-safe low-level call to policy. The policy is registered to the parties.
        /// The policy address is already validated during policy audit and authorization.
        /// During `onlyAuthorizedPolicy`, the policy is verified about safety.
        //slither-disable-next-line missing-zero-check
        (bool success, bytes memory result) = policy.call(callData);
        if (!success) revert EnforcementFailed("Error during policy enforcement call");
        // expected returned attestation as agreement confirmation
        uint256[] memory attestationIds = abi.decode(result, (uint256[]));
        _registerBatchPolicies(proof, policy, attestationIds, agreement.parties);
        return attestationIds;
    }

    /// @notice Retrieves the first active policy matching the criteria for an account .
    /// @param account Address of the account to evaluate.
    /// @param criteria Encoded data containing parameters for access verification. eg: assetId, holder
    function getActivePolicy(address account, bytes memory criteria) external view returns (bool, address) {
        address[] memory policies = getPolicies(account);
        uint256 policiesLen = policies.length;

        // safe unchecked limited to max policy length
        for (uint256 i = 0; i < policiesLen; i = i.uncheckedInc()) {
            // the first matching criteria is returned
            if (isActivePolicy(account, policies[i], criteria)) {
                return (true, policies[i]);
            }
        }

        return (false, address(0));
    }

    /// @notice Retrieves the list of active policies matching the criteria for an account.
    /// @dev This function filters out policies that are not active, ensuring the returned array
    ///      contains only valid policies. It first creates a temporary array of the same size as `policies`,
    ///      then filters and resizes it to the exact number of valid policies using `slice()`.
    /// @param account Address of the account to evaluate.
    /// @param criteria Encoded data containing parameters for access verification. eg: assetId, holder, groups, etc
    function getActivePolicies(address account, bytes memory criteria) external view returns (address[] memory) {
        address[] memory policies = getPolicies(account);
        address[] memory filtered = new address[](policies.length);
        uint256 policiesLen = policies.length;
        uint256 j = 0; // filtered cursor

        // safe unchecked limited to max policy length
        for (uint256 i = 0; i < policiesLen; i = i.uncheckedInc()) {
            if (!isActivePolicy(account, policies[i], criteria)) continue;
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

    /// @notice Retrieves the list of policies associated with a specific account and content ID.
    /// @param account The address of the account for which policies are being retrieved.
    function getPolicies(address account) public view returns (address[] memory) {
        // https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet-values-struct-EnumerableSet-AddressSet-
        // This operation will copy the entire storage to memory, which can be quite expensive.
        // This is designed to mostly be used by view accessors that are queried without any gas fees.
        // Developers should keep in mind that this function has an unbounded cost,
        /// and using it as part of a state-changing function may render the function uncallable
        /// if the set grows to a point where copying to memory consumes too much gas to fit in a block.
        return _closures[account].values();
    }

    /// @notice Verifies if a specific policy is active for the provided account and criteria.
    /// @param account The address of the user whose compliance is being evaluated.
    /// @param policy The address of the policy contract to check compliance against.
    /// @param criteria Encoded data containing the parameters required to verify access.
    function isActivePolicy(address account, address policy, bytes memory criteria) public view returns (bool) {
        if (!isRegisteredPolicy(account, policy)) return false;
        return _verifyPolicyAccess(account, policy, criteria);
    }

    /// @dev Checks if a policy is registered under the given account.
    /// @param account The address of the user.
    /// @param policy The address of the policy contract.
    /// @return `true` if the policy is registered for the account, otherwise `false`.
    function isRegisteredPolicy(address account, address policy) public view returns (bool) {
        return _closures[account].contains(policy);
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @dev Verifies access permissions by calling the policy contract.
    /// @param account The address of the user requesting access.
    /// @param policy The address of the policy contract.
    /// @param criteria Encoded parameters required for access verification.
    /// @return `true` if the policy grants access, otherwise `false`.
    function _verifyPolicyAccess(address account, address policy, bytes memory criteria) private view returns (bool) {
        bytes memory callData = abi.encodeCall(IPolicy.isAccessAllowed, (account, criteria));
        (bool success, bytes memory result) = policy.staticcall(callData);
        if (!success) return false; // silent failure
        return abi.decode(result, (bool));
    }

    /// @notice Registers a batch of policies for multiple accounts, associating them with a specific policy contract.
    /// @dev Iterates through the list of `parties` and registers each one under the given `policyAddress`.
    ///      Emits a `Registered` event for each account-policy registration.
    /// @param proof A cryptographic proof that verifies the authenticity of the agreement.
    /// @param attestationIds A list of unique identifiers for attestations confirming each registration.
    /// @param policy The address of the policy contract defining access conditions.
    /// @param parties The list of addresses that will be granted access through the policy.
    function _registerBatchPolicies(
        uint256 proof,
        address policy,
        uint256[] memory attestationIds,
        address[] memory parties
    ) private {
        uint256 partiesLen = parties.length;
        // safe unchecked increment, limited to partiesLen
        for (uint256 i = 0; i < partiesLen; i = i.uncheckedInc()) {
            _registerPolicy(parties[i], policy); // associate policy with account
            emit Registered(parties[i], proof, attestationIds[i], policy);
        }
    }

    /// @notice Adds a new policy to an account’s registered policies.
    /// @dev Uses the `_closures` mapping to store the assigned policies for each account.
    ///      This ensures that the account retains a history of the policies it has been granted access to.
    /// @param account The address of the user being assigned the policy.
    /// @param policy The address of the policy contract to associate with the account.
    function _registerPolicy(address account, address policy) private {
        _closures[account].add(policy);
    }
}
