// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IAssetOwnership } from "@synaps3/core/interfaces/assets/IAssetOwnership.sol";
import { IRightsPolicyManager } from "@synaps3/core/interfaces/rights/IRightsPolicyManager.sol";
import { IAttestationProvider } from "@synaps3/core/interfaces/IAttestationProvider.sol";
import { IPolicy } from "@synaps3/core/interfaces/policies/IPolicy.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @title BasePolicy
/// @notice This abstract contract serves as a base for policies that manage access to content.
abstract contract BasePolicy is ReentrancyGuard, IPolicy, ERC165 {
    using LoopOps for uint256;

    // Immutable public variables to store the addresses of the Rights Manager and Ownership.
    IAttestationProvider public immutable ATTESTATION_PROVIDER;
    IRightsPolicyManager public immutable RIGHTS_POLICY_MANAGER;
    IAssetOwnership public immutable ASSET_OWNERSHIP;

    bool private _initialized;
    /// @dev registry to store the relation between holder & account
    mapping(address => mapping(address => uint256)) private _attestations;

    /// @notice Emitted when an enforcement process is successfully completed for a given account and holder.
    /// @param holder The address of the rights holder managing the asset or access.
    /// @param account The address of the user whose access or compliance is being enforced.
    /// @param attestationId The unique identifier of the attestations that confirms compliance or access.
    event AttestedAgreement(address indexed holder, address indexed account, uint256 attestationId);

    /// @dev Thrown when an attempt is made to access content without proper authorization.
    /// This error is used to prevent unauthorized access to content protected by policies or rights.
    error InvalidAssetHolder();

    error InvalidNotSupportedOperation();

    /// @notice Thrown when a function is called by an address other than the authorized Rights Manager.
    /// This restricts access to functions that are intended to be executed only by the Rights Manager.
    error InvalidUnauthorizedCall(string reason);

    /// @dev Thrown when attempting to initialize a policy for unregistered or invalid content.
    error InvalidPolicyInitialization();

    /// @dev This error is thrown when the policy enforcement process fails.
    /// @param reason A descriptive message providing details about the enforcement failure.
    error InvalidEnforcement(string reason);

    /// @dev Thrown when there is an issue with the attestation, such as when an attestation is missing or invalid.
    error InvalidAttestation();

    /// @dev This error is thrown when there is an issue with the initial setup or configuration.
    error InvalidInitialization(string reason);

    /// @dev Modifier to restrict function calls to the Rights Manager address.
    modifier onlyPolicyManager() {
        if (msg.sender != address(RIGHTS_POLICY_MANAGER)) {
            revert InvalidUnauthorizedCall("Only rights policy manager allowed.");
        }
        _;
    }

    /// @dev Modifier to restrict function calls to the Rights Manager address.
    modifier onlyPolicyAuthorizer() {
        if (msg.sender != address(RIGHTS_POLICY_MANAGER.getPolicyAuthorizer())) {
            revert InvalidUnauthorizedCall("Only rights policy authorizer allowed.");
        }
        _;
    }

    /// @notice Marks the contract as initialized and allows further execution.
    /// @dev This modifier sets the `initialized` state to `true` when invoked.
    ///      Use this in functions that require a one-time setup phase.
    ///      Once executed, the contract is considered initialized.
    /// @custom:modifiers setup
    modifier initializer() {
        _initialized = false;
        _;
        _initialized = true;
    }

    /// @notice Ensures that the contract has been properly initialized before execution.
    /// @dev This modifier checks if the `initialized` flag is set to `true`.
    ///      If the contract is not initialized, it reverts with an `InvalidPolicyInitialization` error.
    ///      Use this to restrict access to functions that depend on the contract's initial setup.
    /// @custom:modifiers withValidSetup
    modifier initialized() {
        if (!_initialized) {
            revert InvalidPolicyInitialization();
        }
        _;
    }

    constructor(address rightsPolicyManager, address assetOwnership, address providerAddress) {
        ATTESTATION_PROVIDER = IAttestationProvider(providerAddress);
        RIGHTS_POLICY_MANAGER = IRightsPolicyManager(rightsPolicyManager);
        ASSET_OWNERSHIP = IAssetOwnership(assetOwnership);
    }

    /// @notice Checks if the contract has been initialized.
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    /// @notice Retrieves the attestation id associated with a specific account and rights holder.
    /// @param recipient The address of the account for which the attestation is being retrieved.
    /// @param holder The address of the rights holder with whom the agreement was made.
    function getAttestation(address recipient, address holder) external view returns (uint256) {
        return _attestations[recipient][holder];
    }

    /// @notice Retrieves the terms associated with a specific rights holder.
    /// @dev This function provides access to policy terms based on the rights holder's address.
    /// @return A struct containing the terms applicable to the specified rights holder.
    function resolveTerms(address) external view virtual returns (T.Terms memory) {
        revert InvalidNotSupportedOperation();
    }

    /// @notice Retrieves the terms associated with a specific content ID.
    /// @dev This function allows for querying policy terms based on the unique content identifier.
    /// @return A struct containing the terms applicable to the specified content ID.
    function resolveTerms(uint256) external view virtual returns (T.Terms memory) {
        revert InvalidNotSupportedOperation();
    }

    /// @notice Verifies if a specific account has access to a particular asset based on `assetId`.
    /// @dev Checks the access policy tied to the provided `assetId` to determine if the account has authorized access.
    function isAccessAllowed(address, uint256) external view virtual returns (bool) {
        revert InvalidNotSupportedOperation();
    }

    /// @notice Verifies if a specific account has general holder's access rights,.
    /// @dev This function can be used to check access for broader scopes, such as groups, subscriptions,etc.
    function isAccessAllowed(address, address) external view virtual returns (bool) {
        revert InvalidNotSupportedOperation();
    }

    /// @notice Checks if a given interface ID is supported by this contract.
    /// @param interfaceId The bytes4 identifier of the interface to check for support.
    /// @return A boolean indicating whether the interface ID is supported (true) or not (false).
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPolicy).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Retrieves the address of the attestation provider.
    /// @return The address of the provider associated with the policy.
    function getAttestationProvider() public view returns (address) {
        return address(ATTESTATION_PROVIDER);
    }

    /// @notice Verifies whether the on-chain access terms are satisfied for an account.
    /// @dev The function checks if the provided account complies with the attestation.
    /// @param account The address of the user whose access is being verified.
    function isCompliant(address account, address holder) public view returns (bool) {
        uint256 attestationId = _attestations[account][holder];
        // default uint256 attestation is zero <- means not registered
        if (attestationId == 0) return false; // false if not registered
        return ATTESTATION_PROVIDER.verify(attestationId, account);
    }

    /// @notice Returns the asset holder registered in the ownership contract.
    /// @param assetId the asset ID to retrieve the holder.
    function getHolder(uint256 assetId) public view returns (address) {
        return ASSET_OWNERSHIP.ownerOf(assetId); // Returns the registered owner.
    }

    /// @dev Internal function to commit an agreement and create an attestation.
    ///      The attestation will be stored on-chain and will have a validity period.
    /// @param agreement The agreement structure containing necessary details for the attestation.
    /// @param expireAt The timestamp at which the attestation will expire.
    function _commit(
        address holder,
        T.Agreement memory agreement,
        uint256 expireAt
    ) internal returns (uint256[] memory) {
        bytes memory data = abi.encode(holder, agreement.initiator, address(this), agreement.parties, agreement);
        uint256[] memory attestationIds = ATTESTATION_PROVIDER.attest(agreement.parties, expireAt, data);
        _updateBatchAttestation(holder, attestationIds, agreement.parties);
        return attestationIds;
    }

    /// @notice Updates the attestation records for each account.
    /// @param attestationIds The ID of the attestations.
    /// @param parties The list of account to assign attestation id.
    function _updateBatchAttestation(
        address holder,
        uint256[] memory attestationIds,
        address[] memory parties
    ) private {
        uint256 partiesLen = parties.length;
        for (uint256 i = 0; i < partiesLen; i = i.uncheckedInc()) {
            _attestations[parties[i]][holder] = attestationIds[i];
            emit AttestedAgreement(holder, parties[i], attestationIds[i]);
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
