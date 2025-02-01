// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IAssetOwnership } from "@synaps3/core/interfaces/assets/IAssetOwnership.sol";
import { IRightsPolicyManagerVerifiable } from "@synaps3/core/interfaces/rights/IRightsPolicyManagerVerifiable.sol";
import { IAttestationProvider } from "@synaps3/core/interfaces/base/IAttestationProvider.sol";
import { IPolicy } from "@synaps3/core/interfaces/policies/IPolicy.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @title PolicyBase
/// @notice Abstract contract serving as the base for policies that manage access control and rights enforcement.
/// @dev This contract provides attestation management, agreement handling, and authorization mechanisms.
/// slither-disable-next-line unimplemented-functions
abstract contract PolicyBase is IPolicy, ERC165 {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAttestationProvider public immutable ATTESTATION_PROVIDER;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRightsPolicyManagerVerifiable public immutable RIGHTS_POLICY_MANAGER;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAssetOwnership public immutable ASSET_OWNERSHIP;

    /// @dev Policy state
    bool private _initialized;
    /// @dev registry to store the relation between (context & account) key => attestation
    mapping(bytes32 => uint256) private _attestations;

    /// @notice Emitted when an enforcement process is successfully completed for a given account.
    /// @param context The attested agreement key map relations. eg: (account & holder), (account & asset id)
    /// @param account The address of the user whose access or compliance is being enforced.
    /// @param attestationId The unique identifier of the attestations that confirms compliance or access.
    event AttestedAgreement(bytes32 indexed context, address indexed account, uint256 attestationId);

    /// @notice Emitted when an agreement is committed.
    /// @param holder The address of the rights holder associated with the agreement.
    /// @param partiesCount The number of parties involved in the agreement.
    /// @param totalAmount The total value of the agreement.
    /// @param fees The fees associated with the agreement.
    event AgreementCommitted(address indexed holder, uint256 partiesCount, uint256 totalAmount, uint256 fees);

    /// @dev Thrown when an attempt is made to access content without proper authorization.
    /// This error is used to prevent unauthorized access to content protected by policies or rights.
    error InvalidAssetHolder();

    /// This error is thrown when a method not implemented is called.
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
        if (msg.sender != RIGHTS_POLICY_MANAGER.getPolicyAuthorizer()) {
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
        RIGHTS_POLICY_MANAGER = IRightsPolicyManagerVerifiable(rightsPolicyManager);
        ASSET_OWNERSHIP = IAssetOwnership(assetOwnership);
    }

    /// @notice Checks if the policy has been initialized.
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    /// @notice Retrieves the address of the attestation provider.
    /// @return The address of the provider associated with the policy.
    function getAttestationProvider() external view returns (address) {
        return address(ATTESTATION_PROVIDER);
    }

    /// @notice Checks if a given interface ID is supported by this contract.
    /// @param interfaceId The bytes4 identifier of the interface to check for support.
    /// @return A boolean indicating whether the interface ID is supported (true) or not (false).
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPolicy).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Returns the asset holder registered in the ownership contract.
    /// @param assetId the asset ID to retrieve the holder.
    function getHolder(uint256 assetId) public view returns (address) {
        return ASSET_OWNERSHIP.ownerOf(assetId); // Returns the registered owner.
    }

    /// @notice Retrieves the license id associated with a specific account.
    /// @param account The address of the account for which the attestation is being retrieved.
    /// @param criteria Encoded data containing the parameters required to retrieve attestation.
    /// eg: assetId, holder, groups, etc
    function getLicense(address account, bytes memory criteria) public view returns (uint256) {
        // recompute the composed key based on account and criteria = to match context
        bytes32 key = _computeComposedKey(account, criteria);
        return _attestations[key];
    }

    /// @dev Internal function to commit an agreement and create an attestation.
    /// @param holder The address of the rights holder associated with the agreement.
    /// @param agreement The agreement structure containing necessary details for the attestation.
    /// @param expireAt The timestamp at which the attestation will expire.
    function _commit(
        address holder,
        T.Agreement memory agreement,
        uint256 expireAt
    ) internal returns (uint256[] memory) {
        bytes memory payload = abi.encode(agreement);
        bytes memory data = abi.encode(holder, agreement.initiator, address(this), agreement.parties, payload);
        // register policy metrics in the holder context to track analytics
        emit AgreementCommitted(holder, agreement.parties.length, agreement.total, agreement.fees);
        return ATTESTATION_PROVIDER.attest(agreement.parties, expireAt, data);
    }

    /// @notice Internal function to create and register an attestation.
    /// @dev This function stores the attestation on-chain and emits an event for tracking purposes.
    /// @param account The address of the user for whom the attestation is being created.
    /// @param context Encoded data representing the context (e.g., holder address or asset details).
    /// @param attestationId The unique identifier for the attestation being created.
    function _setAttestation(address account, bytes memory context, uint256 attestationId) internal {
        // Composed key to store the relationship between account and context.
        bytes32 key = _computeComposedKey(account, context);
        _attestations[key] = attestationId;
        emit AttestedAgreement(key, account, attestationId);
    }

    /// @notice Computes a unique key by combining a context and an account address.
    /// @dev This key is used to map relationships between accounts and context data in the `_attestations` mapping.
    /// @param account The address of the user for whom the key is being generated.
    /// @param context Encoded data representing the context for the operation. eg: holder, assetId, etc
    /// @return A `bytes32` hash that uniquely identifies the context-account pair.
    function _computeComposedKey(address account, bytes memory context) private pure returns (bytes32) {
        // Combines the user address (`account`) with a specific context (`context`)
        // to generate a unique key. This is useful for representing relationships like:
        // - Holder-level licenses: account + "holder"
        // - Resource-level licenses: account + assetId
        // - Group-level licenses: account + "groupId", etc etc
        // This answers: "the account has a license for the asset id?""..
        return keccak256(abi.encodePacked(account, context));
    }
}
