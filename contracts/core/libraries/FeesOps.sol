// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { C } from "@synaps3/core/primitives/Constants.sol";

/// @title FeesOps
/// @notice Library for handling fee-related calculations and operations.
library FeesOps {
    /// @notice Checks if the given fee value is expressed in basis points (bps).
    /// @param fees The fee amount to check.
    function isBasePoint(uint256 fees) internal pure returns (bool) {
        // 10,000 bps = 100%
        return (fees <= C.BPS_MAX);
    }

    /// @notice Checks if the given fee value is expressed in nominal percentage.
    /// @param fees The fee amount to check.
    function isNominal(uint256 fees) internal pure returns (bool) {
        // SCALE_FACTOR = 100% nominal
        return (fees <= C.SCALE_FACTOR);
    }

    /// @dev Calculates the percentage of `amount` based on the given `bps` (basis points).
    /// @param amount The amount to calculate the percentage of.
    /// @param bps The basis points to use for the calculation.
    function perOf(uint256 amount, uint256 bps) internal pure returns (uint256) {
        // 10 * (5*100) / 10_000
        // move the decimal to integer part, multiply, then divide to compensate
        // solhint-disable-next-line gas-custom-errors
        require(bps <= C.BPS_MAX, "BPS cannot be greater than 10_000");
        return (amount * bps) / C.BPS_MAX;
    }

    /// @dev Calculates the basis points (`bps`) based on the given percentage.
    /// @param per The percentage to calculate the `bps` for.
    function calcBps(uint256 per) internal pure returns (uint256) {
        return per * C.SCALE_FACTOR;
    }
}
