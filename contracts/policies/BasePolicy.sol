// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Governable } from "contracts/base//Governable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IContentOwnership } from "contracts/interfaces/assets/IContentOwnership.sol";
import { IRightsPolicyManager } from "contracts/interfaces/rightsmanager/IRightsPolicyManager.sol";
import { IAttestationProvider } from "contracts/interfaces/IAttestationProvider.sol";
import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title BasePolicy
/// @notice This abstract contract serves as a base for policies that manage access to content.
abstract contract BasePolicy is Governable, ReentrancyGuard, IPolicy {
    // Immutable public variables to store the addresses of the Rights Manager and Ownership.
    IAttestationProvider public immutable ATTESTATION_PROVIDER;
    IRightsPolicyManager public immutable RIGHTS_POLICY_MANAGER;
    IContentOwnership public immutable CONTENT_OWNERSHIP;

    bool private setupReady;
    /// @dev attestation registry
    mapping(address => uint256) public attestations;

    /// @notice Emitted when an enforcement process is successfully completed for a given account and holder.
    /// @param holder The address of the rights holder managing the content or access.
    /// @param account The address of the user whose access or compliance is being enforced.
    /// @param attestationId The unique identifier of the attestation that confirms compliance or access.
    event AccessGranted(address indexed holder, address indexed account, uint256 attestationId);

    /// @dev Thrown when an attempt is made to access content without proper authorization.
    /// This error is used to prevent unauthorized access to content protected by policies or rights.
    error InvalidContentHolder();

    /// @notice Thrown when a function is called by an address other than the authorized Rights Manager.
    /// This restricts access to functions that are intended to be executed only by the Rights Manager.
    error InvalidCallOnlyRightsManagerAllowed();

    /// @dev Thrown when attempting to initialize a policy for unregistered or invalid content.
    /// @param policyAddress The address of the policy contract that is attempting to be initialized.
    error InvalidPolicyInitialization(address policyAddress);

    /// @dev This error is thrown when the policy enforcement process fails.
    /// @param reason A descriptive message providing details about the enforcement failure.
    error InvalidEnforcement(string reason);

    /// @dev Thrown when there is an issue with the attestation, such as when an attestation is missing or invalid.
    error InvalidAttestation();

    /// @dev This error is thrown when there is an issue with the initial setup or configuration.
    error InvalidInitialization(string reason);

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

    /// @notice Determines if the user has access to specific content based on `contentId`.
    /// @dev By default, this function only checks if the account complies with attestation requirements.
    function isAccessAllowed(address account, uint256) external view virtual returns (bool) {
        // Default behavior: only check attestation compliance.
        return isCompliant(account);
    }

    /// @notice Retrieves the attestation associated with a specific account.
    /// @param recipient The address of the account involved in the attestation.
    function getAttestation(address recipient) external view returns (uint256) {
        return attestations[recipient];
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
        uint256 attestationId = attestations[account];
        if (attestationId == 0) return false; // must be registered
        return ATTESTATION_PROVIDER.verify(attestationId, address(this), account);
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
    function _commit(address holder, T.Agreement memory agreement, uint256 expireAt) internal returns (uint256) {
        bytes memory data = abi.encode(holder, agreement); // bind agreement and rights holder..
        uint256 attestationId = ATTESTATION_PROVIDER.attest(agreement.parties, expireAt, data);
        _updateBatchAttestation(holder, attestationId, agreement.parties);
        return attestationId;
    }

    /// @notice Updates the attestation records for each account.
    /// @param attestationId The ID of the attestation.
    /// @param parties The list of account to assign attestation id.
    function _updateBatchAttestation(address holder, uint256 attestationId, address[] memory parties) private {
        uint256 partiesLen = parties.length;
        for (uint256 i = 0; i < partiesLen; i++) {
            attestations[parties[i]] = attestationId;
            emit AccessGranted(holder, parties[i], attestationId);
        }
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
