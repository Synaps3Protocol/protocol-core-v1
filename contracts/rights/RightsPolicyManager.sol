// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IPolicy } from "@synaps3/core/interfaces/policies/IPolicy.sol";
import { IAgreementSettler } from "@synaps3/core/interfaces/financial/IAgreementSettler.sol";
import { IRightsPolicyManager } from "@synaps3/core/interfaces/rights/IRightsPolicyManager.sol";
import { IRightsPolicyAuthorizer } from "@synaps3/core/interfaces/rights/IRightsPolicyAuthorizer.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

contract RightsPolicyManager is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IRightsPolicyManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ERC165Checker for address;
    using LoopOps for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAgreementSettler public immutable AGREEMENT_SETTLER;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRightsPolicyAuthorizer public immutable RIGHTS_AUTHORIZER;

    /// @dev Mapping to store the access control list for each content holder and account.
    mapping(address => EnumerableSet.AddressSet) private _closures;

    /// @notice Emitted when access rights are granted to an account based on a specific policy.
    /// @param account The address of the account to which the policy applies.
    /// @param proof A unique identifier for the agreement between holder and account.
    /// @param attestationId A unique identifier for the attestation that confirms the registration.
    /// @param policy The address of the registered policy governing the access rights.
    event PolicyRegistered(address indexed account, uint256 proof, uint256 attestationId, address policy);

    /// @dev Error thrown when attempting to operate on a policy that has not
    /// been delegated rights for the specified content.
    /// @param policy The address of the policy contract attempting to access rights.
    /// @param holder the asset rights holder.
    error InvalidNotRightsDelegated(address policy, address holder);
    error InvalidPolicyEnforcement(string);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address agreementSettler, address rightsAuthorizer) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        AGREEMENT_SETTLER = IAgreementSettler(agreementSettler);
        RIGHTS_AUTHORIZER = IRightsPolicyAuthorizer(rightsAuthorizer);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Retrieves the address of the Rights Policies Authorizer contract.
    /// @return The address of the contract responsible for authorizing rights policies.
    function getPolicyAuthorizer() external view returns (address) {
        return address(RIGHTS_AUTHORIZER);
    }

    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @dev This function verifies the policy's authorization, executes the agreement and registers the policy.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param holder The rights holder whose authorization is required for accessing the asset.
    /// @param policyAddress The address of the policy contract managing the agreement.
    function registerPolicy(uint256 proof, address holder, address policyAddress) external returns (uint256[] memory) {
        // 1- retrieves the agreement and marks it as settled..
        T.Agreement memory agreement = AGREEMENT_SETTLER.settleAgreement(proof, holder);
        // 2- only authorized policies by holder can be registered..
        if (!RIGHTS_AUTHORIZER.isPolicyAuthorized(policyAddress, holder)) {
            revert InvalidNotRightsDelegated(policyAddress, holder);
        }

        // type safe low level call to policy
        // the policy is registered to the parties..
        bytes memory callData = abi.encodeCall(IPolicy.enforce, (holder, agreement));
        (bool success, bytes memory result) = policyAddress.call(callData);
        if (!success) revert InvalidPolicyEnforcement("Error during policy enforcement call");

        // expected returned attestation as agreement confirmation
        uint256[] memory attestationIds = abi.decode(result, (uint256[]));
        _registerBatchPolicies(proof, policyAddress, attestationIds, agreement.parties);
        return attestationIds;
    }

    /// @notice Retrieves the first active policy matching the criteria for an account in LIFO order.
    /// @param account Address of the account to evaluate.
    /// @param criteria Encoded data containing parameters for access verification. eg: assetId, holder
    function getActivePolicy(address account, bytes memory criteria) external view returns (bool, address) {
        address[] memory policies = getPolicies(account);
        uint256 i = policies.length;

        // Get the first active policy in LIFO order and return it
        while (i > 0) {
            address currentPolicy = policies[i - 1];
            if (isActivePolicy(account, currentPolicy, criteria)) {
                return (true, currentPolicy);
            }

            // safe unchecked
            // limited to i > 0
            i = i.uncheckedDec();
        }

        return (false, address(0));
    }

    /// @notice Retrieves the list of active policies matching the criteria for an account.
    /// @param account Address of the account to evaluate.
    /// @param criteria Encoded data containing parameters for access verification. eg: assetId, holder
    function getActivePolicies(address account, bytes memory criteria) external view returns (address[] memory) {
        address[] memory policies = getPolicies(account);
        address[] memory filtered = new address[](policies.length);
        uint256 policiesLen = policies.length;
        uint256 j = 0; // filtered cursor

        for (uint256 i = 0; i < policiesLen; i = i.uncheckedInc()) {
            if (!isActivePolicy(account, policies[i], criteria)) continue;
            filtered[j] = policies[i];

            // safe unchecked
            // limited to i increment = max policy length
            j = j.uncheckedDec();
        }

        return filtered;
    }

    /// @notice Retrieves the list of policys associated with a specific account and content ID.
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
        // verify if the policy were registered for account address and comply with the criteria
        bool registeredPolicy = _closures[account].contains(policy);
        if (!registeredPolicy) return false; // fail fast: not registered policy
        // ask to policy about the access for account address
        bytes memory callData = abi.encodeCall(IPolicy.isAccessAllowed, (account, criteria));
        (bool success, bytes memory result) = policy.staticcall(callData);
        if (!success) return false; // silent failure
        // ok => verified access
        bool ok = abi.decode(result, (bool));
        return ok;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Registers a new policy for a list of accounts, granting access based on a specific policy contract.
    /// @param proof A cryptographic proof that verifies the authenticity of the agreement.
    /// @param attestationIds A list of unique identifiers for the attestation that confirms the registration.
    /// @param policyAddress The address of the policy contract responsible for validating the access conditions.
    /// @param parties The addresses of the accounts to be granted access through the policy.
    function _registerBatchPolicies(
        uint256 proof,
        address policyAddress,
        uint256[] memory attestationIds,
        address[] memory parties
    ) private {
        uint256 partiesLen = parties.length;
        for (uint256 i = 0; i < partiesLen; i = i.uncheckedInc()) {
            uint256 attestationId = attestationIds[i];
            _closures[parties[i]].add(policyAddress); // associate the policy with party account
            emit PolicyRegistered(parties[i], proof, attestationId, policyAddress);
        }
    }
}
