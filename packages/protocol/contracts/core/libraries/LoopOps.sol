// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title LoopOps - Library for Optimized Loop Operations
/// @notice Provides a helper function to work with unchecked increment operations in loops.
/// @dev Using unchecked increments can save gas by avoiding overflow checks in loops,
///      which is beneficial in cases where overflow is unlikely or impossible due to constraints.
library LoopOps {
    /// @notice Increments a given integer by 1 without overflow checks.
    /// @dev The `unchecked` keyword is used to skip overflow checks, reducing gas costs.
    ///      This is safe when you know that the variable `i` will not reach the maximum value of `uint256`.
    /// @param i The integer to increment.
    /// @return j The incremented integer.
    function uncheckedInc(uint256 i) internal pure returns (uint256 j) {
        unchecked {
            j = i + 1;
        }
    }
}
