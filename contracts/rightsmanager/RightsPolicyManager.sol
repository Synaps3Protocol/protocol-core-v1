// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { LedgerUpgradeable } from "contracts/base/upgradeable/LedgerUpgradeable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";

import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { ITreasury } from "contracts/interfaces/economics/ITreasury.sol";
import { IRightsPolicyManager } from "contracts/interfaces/rightsmanager/IRightsPolicyManager.sol";
import { IRightsPolicyAuthorizer } from "contracts/interfaces/rightsmanager/IRightsPolicyAuthorizer.sol";
import { IRightsAccessAgreement } from "contracts/interfaces/rightsmanager/IRightsAccessAgreement.sol";
import { TreasuryHelper } from "contracts/libraries/TreasuryHelper.sol";
import { FeesHelper } from "contracts/libraries/FeesHelper.sol";
import { T } from "contracts/libraries/Types.sol";

contract RightsPolicyManager is
    Initializable,
    UUPSUpgradeable,
    LedgerUpgradeable,
    GovernableUpgradeable,
    ReentrancyGuardUpgradeable,
    IRightsPolicyManager
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using TreasuryHelper for address;
    using FeesHelper for uint256;

    /// Preventing accidental/malicious changes during contract reinitializations.
    ITreasury public immutable TREASURY;
    IRightsAccessAgreement public immutable RIGTHS_AGREEMENT;
    IRightsPolicyAuthorizer public immutable RIGHTS_AUTHORIZER;

    /// @dev Mapping to store the access control list for each content holder and account.
    mapping(address => EnumerableSet.AddressSet) private acl;

    /// @notice Emitted when access rights are granted to an account based on a policy.
    /// @param account The address of the account granted access.
    /// @param proof A unique identifier for the agreement or transaction.
    /// @param policy The policy contract address governing the access.
    event AccessGranted(address indexed account, bytes32 indexed proof, address indexed policy);

    /// @dev Error thrown when attempting to operate on a policy that has not
    /// been delegated rights for the specified content.
    /// @param policy The address of the policy contract attempting to access rights.
    /// @param holder The content rights holder.
    error InvalidNotRightsDelegated(address policy, address holder);

    /// @dev Error thrown when a policy registration fails to execute.
    /// @param reason A string providing the reason for the failure.
    error InvalidPolicyRegistration(string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address treasury, address rightsAgreement, address rightsAuthorizer) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        TREASURY = ITreasury(treasury);
        RIGTHS_AGREEMENT = IRightsAccessAgreement(rightsAgreement);
        RIGHTS_AUTHORIZER = IRightsPolicyAuthorizer(rightsAuthorizer);
    }

    /// @notice Initializes the proxy state.
    function initialize() public initializer {
        __Ledger_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Governable_init(msg.sender);
    }

    /// @notice Disburses funds from the contract to the vault.
    /// @param currency The address of the ERC20 token to disburse tokens.
    /// @dev This function can only be called by governance or an authorized entity.
    function disburse(address currency) external onlyGov nonReentrant {
        // transfer all the funds to the treasury..
        uint256 amount = address(this).balanceOf(currency);
        address target = TREASURY.getVaultAddress();
        target.transfer(amount, currency); // sent amount to vault..
        emit FeesDisbursed(target, amount, currency);
    }

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @dev This function withdraws funds from the caller's balance and transfers them to the recipient.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external nonReentrant {
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToWithdraw();
        _subLedgerEntry(msg.sender, amount, currency);
        recipient.transfer(amount, currency);
        emit FundsWithdrawn(recipient, amount, currency);
    }

    /// @notice Retrieves the first active policy for a specific account and content id in LIFO order.
    /// @param account The address of the account to evaluate.
    /// @param contentId The ID of the content to evaluate policies for.
    function getActivePolicy(address account, uint256 contentId) public view returns (bool, address) {
        address[] memory policies = getPolicies(account);
        uint256 i = policies.length - 1;

        while (true) {
            bool comply = _verifyPolicy(account, contentId, policies[i]);
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
    /// @param policyAddress The address of the policy contract managing the agreement.
    function registerPolicy(bytes32 proof, address policyAddress) public payable nonReentrant {
        // retrieves the agreement and marks it as settled..
        T.Agreement memory a7t = RIGTHS_AGREEMENT.settleAgreement(proof);
        // only authorized policies by holder could be registered..
        if (!RIGHTS_AUTHORIZER.isPolicyAuthorized(policyAddress, a7t.holder))
            revert InvalidNotRightsDelegated(policyAddress, a7t.holder);

        // deposit the total amount to contract during policy registration..
        // the available amount is registerd to policy to later allow withdrawals..
        // IMPORTANT: the process of distribution registration to accounts should be done in policies logic.
        msg.sender.safeDeposit(a7t.total, a7t.currency);
        // validate policy execution register funds and access policy..
        try IPolicy(policyAddress).exec(a7t) {
            // if-only-if policy execution is successful
            _sumLedgerEntry(policyAddress, a7t.available, a7t.currency);
            _registerPolicy(a7t.account, policyAddress);
            emit AccessGranted(a7t.account, proof, policyAddress);
        } catch Error(string memory reason) {
            // catch revert with a reason string argument..
            // revert(string) and require(false, “reason”)
            revert InvalidPolicyRegistration(reason);
        } catch (bytes memory custom) {
            // still we don't have a custom error catch to handle this
            // and we need a way to inform the explicit reason why the policy execution failed
            // https://github.com/ethereum/solidity/issues/11278
            bytes4 expectedCustom = bytes4(custom);
            bytes4 execError = bytes4(keccak256("InvalidExecution(string)"));
            bytes4 setupError = bytes4(keccak256("InvalidSetup(string)"));
            if (execError == expectedCustom || setupError == expectedCustom) {
                string memory reason = abi.decode(custom[4:], (string));
                revert InvalidPolicyRegistration(reason);
            }
        }
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

    /// @notice Registers a new policy for a specific account and policy, maintaining a chain of precedence.
    /// @param account The address of the account to be granted access through the policy.
    /// @param policy The address of the policy contract responsible for validating the conditions of the license.
    function _registerPolicy(address account, address policy) private {
        // Add the new policy as the most recent, following LIFO precedence
        // an account could be bounded to different policies to access contents
        acl[account].add(policy);
    }

    /// @notice Verifies whether access is allowed for a specific account and content based on a given license.
    /// @param account The address of the account to verify access for.
    /// @param contentId The ID of the content for which access is being checked.
    /// @param policy The address of the license policy contract used to verify access.
    function _verifyPolicy(address account, uint256 contentId, address policy) private view returns (bool) {
        // if not registered license policy..
        if (policy == address(0)) return false;
        IPolicy policy_ = IPolicy(policy);
        return policy_.comply(account, contentId);
    }

    // TODO potential improvement getChainedPolicies
    // allowing concatenate policies to evaluate compliance...
    // This approach supports complex access control scenarios where multiple factors need to be considered.

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
