// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "contracts/core/primitives/Types.sol";

/// @title Tollgate Interface
/// @dev This interface defines the essential functions for managing fees and the currencies
/// accepted within the platform. It ensures the platform can set, retrieve, and validate fees,
/// as well as maintain a registry of supported currencies for different operational contexts.
interface ITollgate {
    /// @notice Sets a new fee for a specific context and currency.
    /// @param ctx The context for which the new fee is being set (e.g., registration, access).
    /// @param fee The new fee to set (can be flat fee or basis points depending on the context).
    /// @param currency The currency associated with the fee (can be ERC-20 or native currency).
    function setFees(T.Context ctx, uint256 fee, address currency) external;

    /// @notice Retrieves the fees for a specified context and currency.
    /// @param ctx The context for which to retrieve the fees.
    /// @param currency The address of the currency for which to retrieve the fees.
    function getFees(T.Context ctx, address currency) external view returns (uint256);

    /// @notice Checks if a currency is supported for a given context.
    /// @param ctx The context under which the currency is being checked.
    /// @param currency The address of the currency to check.
    function isCurrencySupported(T.Context ctx, address currency) external view returns (bool);

    /// @notice Returns the list of supported currencies for a given context.
    /// @param ctx The context under which the currencies are being queried.
    function supportedCurrencies(T.Context ctx) external view returns (address[] memory);
}
