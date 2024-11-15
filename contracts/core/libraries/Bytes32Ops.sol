// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Bytes32 Ops Library
/// @notice Provides functions to convert bytes32 to other data types.
/// @dev Contains functions to convert a bytes32 value to an address with proper alignment.
library Bytes32Ops {
    /// @notice Converts a bytes32 value to an address.
    /// @param _bytes The bytes32 value to convert.
    /// @dev This function uses inline assembly to perform the conversion.
    function toAddress(bytes32 _bytes) internal pure returns (address addr) {
        assembly {
            // AND operation with mask to retain only the lower 20 bytes.
            // https://github.com/ethereum/solidity-examples/blob/master/docs/bytes/Bytes.md
            // Example:
            // Address to encode: 0x1234567890abcdef1234567890abcdef12345678
            // Encoded bytes32: 0x000000000000000000000000EFBBD14082cF2FbCf9Badc7ee619F0f4e36D0A5B
            // Mask:            0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            // Result:          0x0000000000000000000000001234567890abcdef1234567890abcdef12345678

            // Perform the AND operation to keep only the lower 20 bytes (address size)
            addr := and(_bytes, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }

    /// @notice Converts a bytes32 value to a uint256.
    /// @param _bytes The bytes32 value to convert.
    function toUint256(bytes32 _bytes) internal pure returns (uint256) {
        return uint256(_bytes);
    }
}
