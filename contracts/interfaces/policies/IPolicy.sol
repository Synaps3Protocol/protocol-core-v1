// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "contracts/libraries/Types.sol";

/// @title IPolicyDescriptor
/// @notice Interface for managing access to content based on licensing terms.
/// @dev This interface defines the basic information about the policy, such as its name and description.
interface IPolicy {
    /// @notice Returns the string identifier associated with the policy.
    /// @dev This function provides a way to identify the specific policy being used.
    function name() external pure returns (string memory);

    /// @notice Returns the business/strategy model implemented by the policy.
    /// @dev A description of the business model as bytes, allowing more complex representations (such as encoded data).
    function description() external pure returns (string memory);

    /// @notice Initializes the policy with specific data for a given holder.
    /// @dev Only the Rights Policies Authorizer contract has permission to call this function.
    /// @param holder The address of the holder for whom the policy is being initialized.
    /// @param init Initialization data required to configure the policy.
    function initialize(address holder, bytes calldata init) external;

    /// @notice Executes the agreement between the asset holder and the account based on the policy's rules.
    /// @dev Rights Policies Manager contract should be the only one allowed to call this method.
    /// @param holder The rights holder whose authorization is required for accessing the asset.
    /// @param agreement An object containing the terms agreed upon between the asset holder and the user.
    function enforce(address holder, T.Agreement calldata agreement) external returns (uint256);

    /// @notice Retrieves the address of the attestation provider.
    /// @return The address of the provider associated with the policy.
    function getAttestationProvider() external view returns (address);

    /// @notice Retrieves the attestation associated with a specific account.
    /// @param recipient The address of the account involved in the attestation.
    function getAttestation(address recipient) external view returns (uint256);

    /// @notice Determines if the user has access to specific content based on `assetId`.
    /// @dev Evaluates the provided `assetId` and returns true if access is allowed.
    /// @param account The user address whose access is being checked.
    /// @param assetId The unique identifier of the asset to verify access for.
    function isAccessAllowed(address account, uint256 assetId) external view returns (bool);

    /// @notice Retrieves the terms associated with a specific rights holder.
    /// @dev This function provides access to policy terms based on the rights holder's address.
    /// @param holder The address of the rights holder for whom terms are being resolved.
    /// @return A struct containing the terms applicable to the specified rights holder.
    function resolveTerms(address holder) external view returns (T.Terms memory);

    /// @notice Retrieves the terms associated with a specific content ID.
    /// @dev This function allows for querying policy terms based on the unique content identifier.
    /// @param assetId The unique identifier of the asset for which terms are being resolved.
    /// @return A struct containing the terms applicable to the specified content ID.
    function resolveTerms(uint256 assetId) external view returns (T.Terms memory);
}
