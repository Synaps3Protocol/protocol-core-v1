// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title RollingOps
/// @notice Library providing utility functions for managing rolling arrays with a fixed window size.
library RollingOps {
    struct Rolling {
        // Maximum size of the array before rolling out old values.
        uint256 _maxWindowSize;
        // Storage of set values
        bytes32[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 value => uint256) _positions;
    }

    struct AddressArray {
        Rolling _inner;
    }

    /// @dev If window is not configured, default use 5
    uint256 internal constant MAX_DEFAULT_WINDOW = 5;

    /// @dev Error thrown when attempting to access an index that is out of bounds.
    error IndexOutOfBounds();

    /// @dev Error thrown when attempting to set an invalid window size (must be greater than zero).
    error InvalidZeroWindowSize();

    /// @dev Sets the maximum window size of the set.
    function configure(AddressArray storage set, uint256 window_) internal {
        if (window_ == 0) revert InvalidZeroWindowSize();
        set._inner._maxWindowSize = window_;
    }

    /// @dev Adds a value to the set, rolling out the oldest if the max window size is reached.
    function roll(AddressArray storage set, address value) internal {
        _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /// @dev Checks if a value exists in the set. O(1).
    function contains(AddressArray storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /// @dev Returns the number of values in the set. O(1).
    function length(AddressArray storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /// @dev Returns the maximum window size.
    function window(AddressArray storage set) internal view returns (uint256) {
        return _window(set._inner);
    }

    /// @dev Returns the value stored at position `index` in the set. O(1).
    function at(AddressArray storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /// @dev Returns all values stored in the set as an array.
    function values(AddressArray storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    /// @dev Internal function to add a value to the rolling set.
    ///      - If the value already exists, it swaps its position with the last element.
    ///      - If the set exceeds the maximum window size, the oldest element is removed.
    ///      - Finally, the new value is added to the set.
    /// @param set The Rolling storage set to modify.
    /// @param value The new value to add to the set.
    function _add(Rolling storage set, bytes32 value) private {
        // If the value already exists, move it to the latest position and return.
        if (_contains(set, value)) {
            _swap(set, value);
            return;
        }

        // If the set has reached its maximum window size, remove the oldest value.
        // Example: [A, B, C] -> Adding D -> Rolls out A -> [B, C, D]
        if (_length(set) >= _window(set)) {
            _rollout(set);
        }

        _rollin(set, value);
    }

    /// @dev Internal function to reposition an existing value in the set by swapping it
    ///      with the last element. This helps maintain order while avoiding duplicates.
    /// @param set The Rolling storage set containing the values.
    /// @param value The value that already exists in the set and needs to be repositioned.
    function _swap(Rolling storage set, bytes32 value) private {
        // Retrieve the last element's index and value.
        uint256 lastIndex = _length(set) - 1;
        // positions use base 1 indexes
        uint256 index = set._positions[value] - 1;
        bytes32 lastValue = set._values[lastIndex];
        bytes32 currentValue = set._values[index];
        // Retrieve the index of the existing value to swap.
        if (index == lastIndex) return;

        // Swap the existing value with the last value.
        set._values[lastIndex] = currentValue;
        set._values[index] = lastValue;
        // Swap positions
        set._positions[lastValue] = index + 1;
        set._positions[currentValue] = lastIndex + 1;
    }

    /// @dev Internal function to insert a value into the set.
    function _rollin(Rolling storage set, bytes32 value) private {
        set._values.push(value);
        set._positions[value] = _length(set);
    }

    /// @dev Internal function to remove the oldest value in the set and shift values.
    function _rollout(Rolling storage set) private {
        // eg. zero base, avoid out of index
        bytes32 oldest = set._values[0];
        delete set._positions[oldest];

        for (uint256 i = 0; i < _window(set) - 1; ) {
            // original         = [A,B,C]
            // i = 0; index = 1 = [B,B,C]
            // i = 1; index = 2 = [B,C,C]
            uint256 index = i + 1;
            set._values[i] = set._values[index];
            set._positions[set._values[i]] = index;

            // safe unchecked limited to max window
            unchecked {
                ++i;
            }
        }

        // removed remaining duplicated
        set._values.pop(); // [B,C] >> C
    }

    /// @dev Returns true if the value is in the set. O(1).
    function _contains(Rolling storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /// @dev Returns the number of values currently in the set. O(1).
    function _length(Rolling storage set) private view returns (uint256) {
        return set._values.length;
    }

    /// @dev Returns all values in the set as an array.
    function _at(Rolling storage set, uint256 index) private view returns (bytes32) {
        if (index >= _length(set)) revert IndexOutOfBounds();
        return set._values[index];
    }

    /// @dev Returns the maximum window size.
    function _window(Rolling storage set) private view returns (uint256) {
        return set._maxWindowSize == 0 ? MAX_DEFAULT_WINDOW : set._maxWindowSize;
    }

    /// @dev Returns all values in the set as an array.
    function _values(Rolling storage set) private view returns (bytes32[] memory) {
        return set._values;
    }
}
