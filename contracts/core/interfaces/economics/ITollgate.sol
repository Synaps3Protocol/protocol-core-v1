// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
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
    /// @param target The context or address for which the fee is being retrieved.
    /// @param currency The address of the currency for which to retrieve the fee.
    /// @return The fee value associated with the given parameters.
    function getFees(address target, address currency) external view returns (uint256, T.Scheme);

    /// @notice Returns the list of supported currencies for a given target.
    /// @param target The context or address for which to retrieve supported currencies.
    /// @return An array of supported currency addresses.
    function supportedCurrencies(address target) external view returns (address[] memory);

    /// @notice Returns true if currency is supported by target.
    /// @param target The context or address for which to verify supported currencies.
    /// @param currency The address of the currency to check.
    /// @return True if the currency is supported, false otherwise.
    function isSupportedCurrency(address target, address currency) external view returns (bool);
}
