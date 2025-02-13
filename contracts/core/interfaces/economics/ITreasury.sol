// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IBalanceOperator } from "@synaps3/core/interfaces/base/IBalanceOperator.sol";

/// @title ITreasury Interface
/// @notice Defines the standard functions for a Treasury contract.
interface ITreasury is IBalanceOperator {
    /// @notice Collects accrued fees for a specified currency from an authorized fee collector.
    /// @param collector The address of an authorized fee collector.
    /// @param currency The address of the currency for which fees are being collected.
    function collectFees(address collector, address currency) external;
}
