// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title ArrayOps
/// @notice Library providing utility functions for manipulating arrays in memory.
library ArrayOps {
    /// @notice Returns a new array containing only the first `cap` elements.
    /// @dev Creates a new array with a maximum size of `cap` and copies
    ///      only the first `cap` elements from the original array.
    /// @param array The input array from which elements will be copied.
    /// @param cap The maximum number of elements to keep in the new array.
    /// @return sliced A new array containing only the first `cap` elements.
    function slice(address[] memory array, uint256 cap) internal pure returns (address[] memory sliced) {
        if (cap > array.length) cap = array.length; // Ensure cap does not exceed array length
        sliced = new address[](cap);

        for (uint256 i = 0; i < cap; i++) {
            sliced[i] = array[i];
        }
    }
}
