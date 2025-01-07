// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

/// @title Tollgate Interface
/// @dev This interface defines the essential functions for managing fees and the currencies
/// accepted within the platform. It ensures the platform can set, retrieve, and validate fees,
/// as well as maintain a registry of supported currencies for different operational contexts.
interface ITollgate {
    /// @notice Sets or updates a fee for a specific target and currency.
    /// @param scheme The fee representation scheme (e.g., flat, nominal, or basis points).
    /// @param target The target context for which the fee is being set.
    /// @param fee The new fee value to set.
    /// @param currency The currency associated with the fee (ERC-20 or native).
    function setFees(T.Scheme scheme, address target, uint256 fee, address currency) external;

    /// @notice Retrieves the fee value for a specific target and currency.
    /// @param scheme The fee representation scheme.
    /// @param target The context or address for which the fee is being retrieved.
    /// @param currency The address of the currency for which to retrieve the fee.
    /// @return The fee value associated with the given parameters.
    function getFees(T.Scheme scheme, address target, address currency) external view returns (uint256);

    /// @notice Checks if a fee scheme is supported for a given target and currency.
    /// @param scheme The fee representation scheme (flat, nominal, or basis points).
    /// @param target The address or context to check.
    /// @param currency The address of the currency to verify.
    /// @return `true` if the currency is supported, otherwise `false`.
    function isSchemeSupported(T.Scheme scheme, address target, address currency) external view returns (bool);

    /// @notice Returns the list of supported currencies for a given target.
    /// @param target The context or address for which to retrieve supported currencies.
    /// @return An array of supported currency addresses.
    function supportedCurrencies(address target) external view returns (address[] memory);
}
