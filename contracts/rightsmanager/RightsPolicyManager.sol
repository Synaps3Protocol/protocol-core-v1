// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { IRightsPolicyManager } from "contracts/interfaces/rightsmanager/IRightsPolicyManager.sol";
import { IRightsPolicyAuthorizer } from "contracts/interfaces/rightsmanager/IRightsPolicyAuthorizer.sol";
import { IRightsAccessAgreement } from "contracts/interfaces/rightsmanager/IRightsAccessAgreement.sol";
import { T } from "contracts/libraries/Types.sol";

contract RightsPolicyManager is Initializable, UUPSUpgradeable, GovernableUpgradeable, IRightsPolicyManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ERC165Checker for address;

    /// Preventing accidental/malicious changes during contract reinitializations.
    IRightsAccessAgreement public immutable RIGTHS_AGREEMENT;
    IRightsPolicyAuthorizer public immutable RIGHTS_AUTHORIZER;

    /// @dev Mapping to store the access control list for each content holder and account.
    mapping(address => EnumerableSet.AddressSet) private acl;

    /// @notice Emitted when access rights are granted to an account based on a specific policy.
    /// @param account The address of the account to which the policy applies.
    /// @param proof A unique identifier for the agreement, attestation, or transaction that confirms the registration.
    /// @param policy The address of the registered policy governing the access rights.
    event PolicyRegistered(address indexed account, bytes32 proof, address policy);

    /// @dev Error thrown when attempting to operate on a policy that has not
    /// been delegated rights for the specified content.
    /// @param policy The address of the policy contract attempting to access rights.
    /// @param holder The content rights holder.
    error InvalidNotRightsDelegated(address policy, address holder);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address rightsAgreement, address rightsAuthorizer) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        RIGTHS_AGREEMENT = IRightsAccessAgreement(rightsAgreement);
        RIGHTS_AUTHORIZER = IRightsPolicyAuthorizer(rightsAuthorizer);
    }

    /// @notice Initializes the proxy state.
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
    }

    /// @notice Verifies if a specific policy is active for the provided account and criteria.
    /// @param account The address of the user whose compliance is being evaluated.
    /// @param contentId The identifier of the content to validate the policy status.
    /// @param policyAddress The address of the policy contract to check compliance against.
    function isActivePolicy(address account, uint256 contentId, address policyAddress) public view returns (bool) {
        // verify if the policy were registered for account address and comply with the criteria
        IPolicy policy = IPolicy(policyAddress);
        bool registeredPolicy = acl[account].contains(policyAddress);
        return registeredPolicy && policy.isAccessAllowed(account, contentId);
    }

    /// @notice Retrieves the first active policy for a specific account in LIFO order.
    /// @param account The address of the account to evaluate.
    /// @param contentId The identifier of the content to validate the policy status.
    function getActivePolicy(address account, uint256 contentId) public view returns (bool, address) {
        address[] memory policies = getPolicies(account);
        uint256 i = policies.length - 1;

        while (true) {
            bool comply = isActivePolicy(account, contentId, policies[i]);
            if (comply) return (true, policies[i]);
            if (i == 0) break;
            // i == 0 avoids underflow, we can safely decrement using unchecked
            unchecked {
                --i;
            }
        }

        // No active policy found
        return (false, address(0));
    }

    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @dev This function verifies the policy's authorization, executes the agreement and registers the policy.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param holder The rights holder whose authorization is required for accessing the content.
    /// @param policyAddress The address of the policy contract managing the agreement.
    function registerPolicy(bytes32 proof, address holder, address policyAddress) public returns (uint256) {
        // 1- retrieves the agreement and marks it as settled..
        T.Agreement memory agreement = RIGTHS_AGREEMENT.settleAgreement(proof, holder);
        // 2- only authorized policies by holder can be registered..
        if (!RIGHTS_AUTHORIZER.isPolicyAuthorized(policyAddress, holder))
            revert InvalidNotRightsDelegated(policyAddress, holder);

        // After successful policy execution:
        // The policy is registered to the parties..
        uint256 attestationId = IPolicy(policyAddress).enforce(holder, agreement);
        _registerBatchPolicies(proof, policyAddress, agreement.parties);
        return attestationId;
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
        return acl[account].values();
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Registers a new policy for a list of accounts, granting access based on a specific policy contract.
    /// @param proof A cryptographic proof that verifies the authenticity of the agreement.
    /// @param policyAddress The address of the policy contract responsible for validating the access conditions.
    /// @param parties The addresses of the accounts to be granted access through the policy.
    function _registerBatchPolicies(bytes32 proof, address policyAddress, address[] memory parties) private {
        uint256 partiesLen = parties.length;
        for (uint256 i = 0; i < partiesLen; i++) {
            acl[parties[i]].add(policyAddress);
            emit PolicyRegistered(parties[i], proof, policyAddress);
        }
    }
}
