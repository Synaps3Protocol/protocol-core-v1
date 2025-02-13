// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

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
    function setup(address holder, bytes calldata init) external;

    /// @notice Executes the agreement between the asset holder and the account based on the policy's rules.
    /// @dev Rights Policies Manager contract should be the only one allowed to call this method.
    /// @param holder The rights holder whose authorization is required for accessing the asset.
    /// @param agreement An object containing the terms agreed upon between the asset holder and the user.
    function enforce(address holder, T.Agreement calldata agreement) external returns (uint256[] memory);

    /// @notice Verifies whether a specific account has access rights.
    /// @param account The address of the user whose access rights are being verified.
    /// @param criteria Encoded data containing the parameters required to verify access.
    function isAccessAllowed(address account, bytes calldata criteria) external view returns (bool);

    /// @notice Retrieves the license id associated with a specific account.
    /// @param account The address of the account for which the attestation is being retrieved.
    /// @param criteria Encoded data containing the parameters required to retrieve attestation.
    function getLicense(address account, bytes calldata criteria) external view returns (uint256);

    /// @notice Retrieves the terms associated with a specific criteria.
    /// @param criteria Encoded data containing the parameters required to retrieve terms.
    /// @return A struct containing the terms applicable to the matching criteria.
    function resolveTerms(bytes calldata criteria) external view returns (T.Terms memory);

    /// @notice Retrieves the address of the attestation provider.
    /// @return The address of the provider associated with the policy.
    function getAttestationProvider() external view returns (address);
}
