// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { C } from "contracts/libraries/Constants.sol";

library FeesHelper {
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
