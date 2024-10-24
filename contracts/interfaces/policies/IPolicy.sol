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
    function description() external pure returns (bytes memory);

    /// @notice Initializes the policy with the necessary data.
    /// @dev This function allows configuring the policy's rules.
    /// @param init The initialization data to set up the policy.
    function initialize(bytes calldata init) external;

    /// @notice Executes the agreement between the content holder and the account based on the policy's rules.
    /// @dev Rights Policies Manager contract should be the only one allowed to call this method.
    /// @param agreement An object containing the terms agreed upon between the content holder and the user.
    function enforce(T.Agreement calldata agreement) external returns (uint64);

    /// @notice Resolves the provided data to retrieve the access terms.
    /// @dev This function decodes the criteria and returns the corresponding terms for the holder.
    /// @param criteria The data in the policy context used to resolve the terms.
    /// @return T.Terms A struct containing the terms, such as price and currency, for the holder.
    function resolveTerms(bytes calldata criteria) external view returns (T.Terms memory);

    /// @notice Verifies whether the on-chain access terms are satisfied for an account.
    /// @dev The function checks if the provided account complies with the policy terms.
    /// @param account The address of the user whose access is being verified.
    /// @param criteria The data containing the criteria for evaluating access.
    function isCompliant(address account, bytes calldata criteria) external view returns (bool);
}
