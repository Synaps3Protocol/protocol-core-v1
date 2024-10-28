// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Governable } from "contracts/base//Governable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IContentOwnership } from "contracts/interfaces/assets/IContentOwnership.sol";
import { IRightsPolicyManager } from "contracts/interfaces/rightsmanager/IRightsPolicyManager.sol";
import { IBalanceWithdrawable } from "contracts/interfaces/IBalanceWithdrawable.sol";
import { IAttestationProvider } from "contracts/interfaces/IAttestationProvider.sol";
import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { Ledger } from "contracts/base/Ledger.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title BasePolicy
/// @notice This abstract contract serves as a base for policies that manage access to content.
abstract contract BasePolicy is Ledger, Governable, ReentrancyGuard, IPolicy, IBalanceWithdrawable {
    // Immutable public variables to store the addresses of the Rights Manager and Ownership.
    IAttestationProvider public immutable ATTESTATION_PROVIDER;
    IRightsPolicyManager public immutable RIGHTS_POLICY_MANAGER;
    IContentOwnership public immutable CONTENT_OWNERSHIP;
    bool private setupReady;

    /// @dev Error thrown when attempting to access content without proper authorization.
    error InvalidContentHolder();
    /// @notice Error thrown when a function is called by an address other than the Rights Manager.
    error InvalidCallOnlyRightsManagerAllowed();
    /// @dev Error thrown when attempting to access unregistered content.
    error InvalidPolicyInitialization(address);

    /// @dev This error is thrown when there is a failure in the execution process.
    error InvalidExecution(string reason);
    error InvalidAttestation();

    /// @dev This error is thrown when there is an issue with the initial setup or configuration.
    error InvalidSetup(string reason);

    /// @dev Modifier to restrict function calls to the Rights Manager address.
    modifier onlyRM() {
        if (msg.sender != address(RIGHTS_POLICY_MANAGER)) {
            revert InvalidCallOnlyRightsManagerAllowed();
        }
        _;
    }

    /// @notice Marks the contract as initialized and allows further execution.
    /// @dev This modifier sets the `initialized` state to `true` when invoked.
    ///      Use this in functions that require a one-time setup phase.
    ///      Once executed, the contract is considered initialized.
    /// @custom:modifiers setup
    modifier initializer() {
        setupReady = false;
        _;
        setupReady = true;
    }

    /// @notice Ensures that the contract has been properly initialized before execution.
    /// @dev This modifier checks if the `initialized` flag is set to `true`.
    ///      If the contract is not initialized, it reverts with an `InvalidPolicyInitialization` error.
    ///      Use this to restrict access to functions that depend on the contract's initial setup.
    /// @custom:modifiers withValidSetup
    modifier initialized() {
        if (!setupReady) {
            revert InvalidPolicyInitialization(address(this));
        }
        _;
    }

    constructor(address rightsPolicyManager, address contentOwnership, address providerAddress) Governable(msg.sender) {
        ATTESTATION_PROVIDER = IAttestationProvider(providerAddress);
        RIGHTS_POLICY_MANAGER = IRightsPolicyManager(rightsPolicyManager);
        CONTENT_OWNERSHIP = IContentOwnership(contentOwnership);
    }

    /// @notice Retrieves the address of the attestation provider.
    /// @return The address of the provider associated with the policy.
    function getAttestationProvider() public view returns (address) {
        return address(ATTESTATION_PROVIDER);
    }

    /// @notice Verifies whether the on-chain access terms are satisfied for an account.
    /// @dev The function checks if the provided account complies with the attestation.
    /// @param account The address of the user whose access is being verified.
    function isCompliant(address account) public view returns (bool) {
        return ATTESTATION_PROVIDER.verify(address(this), account);
    }

    /// @notice Abstract method to validate access based on the policy's specific context.
    /// @dev Each policy must override this function to define its own validation logic.
    /// @param account The address of the user whose access is being validated.
    /// @param contentId The identifier of the content for which access is being validated.
    function isAccessValid(address account, uint256 contentId) public view virtual returns (bool);

    /// @notice Determines whether access is granted based on the provided contentId.
    /// @dev This function evaluates the provided contentId and returns true if access is granted, false otherwise.
    /// @param account The address of the user whose access is being verified.
    /// @param contentId The identifier of the content for which access is being checked.
    function isAccessAllowed(address account, uint256 contentId) public view returns (bool) {
        address holder = getHolder(contentId);
        if (holder == address(0)) return false;
        // recreate the expected criteria to validate attestation (agreement)
        // if an attestation match means that the contract emmited an access
        // we need to check if the original expected criteria
        return isCompliant(account) && isAccessValid(account, contentId);
    }

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external nonReentrant {
        // Calls the Rights Manager to withdraw the specified amount in the given currency.
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToWithdraw();
        _subLedgerEntry(msg.sender, amount, currency);
        // rights policy manager allows withdraw funds from policy balance and send it to recipient directly.
        // This happens only if the policy has balance and the sender has registered balance in ledger..
        RIGHTS_POLICY_MANAGER.withdraw(recipient, amount, currency);
        emit FundsWithdrawn(recipient, amount, currency);
    }

    /// @notice Returns the content holder registered in the ownership contract.
    /// @param contentId The content ID to retrieve the holder.
    function getHolder(uint256 contentId) public view returns (address) {
        return CONTENT_OWNERSHIP.ownerOf(contentId); // Returns the registered owner.
    }

    /// @dev Internal function to commit an agreement and create an attestation.
    ///      The attestation will be stored on-chain and will have a validity period.
    /// @param agreement The agreement structure containing necessary details for the attestation.
    /// @param expireAt The timestamp at which the attestation will expire.
    function _commit(T.Agreement memory agreement, uint256 expireAt) internal returns (uint256) {
        // Call the SPI instance to register the attestation in the system
        // SPI_INSTANCE.attest() stores the attestation and returns an ID for tracking
        return ATTESTATION_PROVIDER.attest(agreement.parties, expireAt, abi.encode(agreement));
    }

    // /// @dev Distributes the amount based on the provided shares array.
    // /// @param amount The total amount to be allocated.
    // /// @param currency The address of the currency being allocated.
    // /// @param shares An array of Splits structs specifying split percentages and target addresses.
    // function _allocate(
    //     uint256 amount,
    //     address currency,
    //     T.Shares[] memory shares
    // ) private returns (uint256) {
    //     // If there is no distribution, return the full amount.
    //     if (shares.length == 0) return amount;
    //     if (shares.length > 100) {
    //         revert NoDeal(
    //             "Invalid split allocations. Cannot exceed 100."
    //         );
    //     }

    //     uint8 i = 0;
    //     uint256 accBps = 0; // Accumulated base points.
    //     uint256 accTotal = 0; // Accumulated total allocation.

    //     while (i < shares.length) {
    //         // Retrieve base points and target address from the distribution array.
    //         uint256 bps = shares[i].bps;
    //         address target = shares[i].target;
    //         // Safely increment i (unchecked overflow).
    //         unchecked {
    //             ++i;
    //         }

    //         if (bps == 0) continue;
    //         // Calculate and register the allocation for each distribution.
    //         uint256 registeredAmount = amount.perOf(bps);
    //         target.transfer(registeredAmount, currency);
    //         accTotal += registeredAmount;
    //         accBps += bps;
    //     }

    //     // Ensure total base points do not exceed the maximum allowed (100%).
    //     if (accBps > C.BPS_MAX)
    //         revert NoDeal("Invalid split base points overflow.");
    //     return amount - accTotal; // Returns the remaining unallocated amount.
    // }
}
