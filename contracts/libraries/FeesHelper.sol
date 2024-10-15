// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { C } from "contracts/libraries/Constants.sol";

library FeesHelper {
    /// @notice Checks if the given fee value is expressed in basis points (bps).
    /// @param fees The fee amount to check.
    /// @return True if the fee is within the valid basis point range (0 to 10,000), otherwise false.
    function isBasePoint(uint256 fees) internal pure returns (bool) {
        // 10,000 bps = 100%
        return (fees <= C.BPS_MAX);
    }

    /// @notice Checks if the given fee value is expressed in nominal percentage.
    /// @param fees The fee amount to check.
    /// @return True if the fee is within the valid nominal range (0 to SCALE_FACTOR), otherwise false.
    function isNominal(uint256 fees) internal pure returns (bool) {
        // SCALE_FACTOR = 100% nominal
        return (fees <= C.SCALE_FACTOR);
    }

    /// @dev Calculates the percentage of `amount` based on the given `bps` (basis points).
    /// @param amount The amount to calculate the percentage of.
    /// @param bps The basis points to use for the calculation.
    /// @return The percentage of `amount` based on the given `bps`.
    function perOf(uint256 amount, uint256 bps) internal pure returns (uint256) {
        // 10 * (5*100) / 10_000
        require(bps <= C.BPS_MAX, "BPS cannot be greater than 10_000");
        return (amount * bps) / C.BPS_MAX;
    }

    /// @dev Calculates the basis points (`bps`) based on the given percentage.
    /// @param per The percentage to calculate the `bps` for.
    /// @return The `bps` based on the given percentage.
    function calcBps(uint256 per) internal pure returns (uint256) {
        return per * C.SCALE_FACTOR;
    }
}
