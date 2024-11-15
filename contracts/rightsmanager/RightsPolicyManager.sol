// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { AccessControlledUpgradeable } from "contracts/base/upgradeable/AccessControlledUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { IRightsPolicyManager } from "contracts/interfaces/rightsmanager/IRightsPolicyManager.sol";
import { IRightsPolicyAuthorizer } from "contracts/interfaces/rightsmanager/IRightsPolicyAuthorizer.sol";
import { IRightsAccessAgreement } from "contracts/interfaces/rightsmanager/IRightsAccessAgreement.sol";
import { LoopOps } from "contracts/libraries/LoopOps.sol";
import { T } from "contracts/libraries/Types.sol";

contract RightsPolicyManager is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IRightsPolicyManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ERC165Checker for address;
    using LoopOps for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRightsAccessAgreement public immutable RIGHTS_AGREEMENT;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRightsPolicyAuthorizer public immutable RIGHTS_AUTHORIZER;

    /// @dev Mapping to store the access control list for each content holder and account.
    mapping(address => EnumerableSet.AddressSet) private _acl;

    /// @notice Emitted when access rights are granted to an account based on a specific policy.
    /// @param account The address of the account to which the policy applies.
    /// @param attestationId A unique identifier for the attestation that confirms the registration.
    /// @param policy The address of the registered policy governing the access rights.
    event PolicyRegistered(address indexed account, uint256 attestationId, address policy);

    /// @dev Error thrown when attempting to operate on a policy that has not
    /// been delegated rights for the specified content.
    /// @param policy The address of the policy contract attempting to access rights.
    /// @param holder the asset rights holder.
    error InvalidNotRightsDelegated(address policy, address holder);
    error InvalidPolicyEnforcement(string);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address rightsAgreement, address rightsAuthorizer) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        RIGHTS_AGREEMENT = IRightsAccessAgreement(rightsAgreement);
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

    /// @notice Retrieves the list of policys associated with a specific account and content ID.
    /// @param account The address of the account for which policies are being retrieved.
    function getPolicies(address account) public view returns (address[] memory) {
        // https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet-values-struct-EnumerableSet-AddressSet-
        // This operation will copy the entire storage to memory, which can be quite expensive.
        // This is designed to mostly be used by view accessors that are queried without any gas fees.
        // Developers should keep in mind that this function has an unbounded cost,
        /// and using it as part of a state-changing function may render the function uncallable
        /// if the set grows to a point where copying to memory consumes too much gas to fit in a block.
        return _acl[account].values();
    }

    /// @notice Finalizes the agreement by registering the agreed-upon policy, effectively closing the agreement.
    /// @dev This function verifies the policy's authorization, executes the agreement and registers the policy.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param holder The rights holder whose authorization is required for accessing the asset.
    /// @param policyAddress The address of the policy contract managing the agreement.
    function registerPolicy(uint256 proof, address holder, address policyAddress) public returns (uint256) {
        // 1- retrieves the agreement and marks it as settled..
        T.Agreement memory agreement = RIGHTS_AGREEMENT.settleAgreement(proof, holder);
        // 2- only authorized policies by holder can be registered..
        if (!RIGHTS_AUTHORIZER.isPolicyAuthorized(policyAddress, holder)) {
            revert InvalidNotRightsDelegated(policyAddress, holder);
        }

        // type safe low level call to policy
        // the policy is registered to the parties..
        (bool success, bytes memory result) = policyAddress.call(abi.encodeCall(IPolicy.enforce, (holder, agreement)));
        if (!success) revert InvalidPolicyEnforcement("Error during policy enforcement call");
        // expected returned attestation as agreement confirmation
        uint256 attestationId = abi.decode(result, (uint256));
        _registerBatchPolicies(attestationId, policyAddress, agreement.parties);
        return attestationId;
    }

    /// @notice Verifies if a specific policy is active for the provided account and criteria.
    /// @param account The address of the user whose compliance is being evaluated.
    /// @param assetId The identifier of the asset to validate the policy status.
    /// @param policyAddress The address of the policy contract to check compliance against.
    function isActivePolicy(address account, uint256 assetId, address policyAddress) public view returns (bool) {
        // verify if the policy were registered for account address and comply with the criteria
        IPolicy policy = IPolicy(policyAddress);
        bool registeredPolicy = _acl[account].contains(policyAddress);
        return registeredPolicy && policy.isAccessAllowed(account, assetId);
    }

    /// @notice Retrieves the first active policy for a specific account in LIFO order.
    /// @param account The address of the account to evaluate.
    /// @param assetId The identifier of the asset to validate the policy status.
    function getActivePolicy(address account, uint256 assetId) public view returns (bool, address) {
        address[] memory policies = getPolicies(account);
        uint256 i = policies.length - 1;

        while (true) {
            bool comply = isActivePolicy(account, assetId, policies[i]);
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

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Registers a new policy for a list of accounts, granting access based on a specific policy contract.
    /// @param proof A cryptographic proof that verifies the authenticity of the agreement.
    /// @param policyAddress The address of the policy contract responsible for validating the access conditions.
    /// @param parties The addresses of the accounts to be granted access through the policy.
    function _registerBatchPolicies(uint256 proof, address policyAddress, address[] memory parties) private {
        uint256 partiesLen = parties.length;
        for (uint256 i = 0; i < partiesLen; i = i.uncheckedInc()) {
            _acl[parties[i]].add(policyAddress);
            emit PolicyRegistered(parties[i], proof, policyAddress);
        }
    }
}
