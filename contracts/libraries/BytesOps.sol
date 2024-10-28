// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Dynamic Bytes Ops Library
/// @notice Provides functions to convert bytes to other data types.
/// @dev Contains functions to convert a bytes array to an address with proper alignment.
library BytesOps {
    /// @notice Converts a dynamic bytes array to an address.
    /// @param _bytes The bytes array to convert.
    function toAddress(bytes memory _bytes) internal pure returns (address addr) {
        assembly {
            // Load the 32 bytes word from memory, skipping the first 32 bytes (length prefix)
            let data := mload(add(_bytes, 0x20))
            // Right shift to align with Ethereum's memory layout for addresses
            // Addresses are right-aligned (high-order padded) in the EVM
            // https://github.com/ethereum/solidity-examples/blob/master/docs/bytes/Bytes.md
            // 96 bits = 12 bytes of padding x 8 bits each byte
            // high-order = padding + data (on the left side in big-endian notation)
            // low-order = data + padding (on the right side in big-endian notation)
            // E.g., before shift: 0x11223344556677889900aabbccddeeff00112233000000000000000000000000
            // E.g., after shift:  0x00000000000000000000000011223344556677889900aabbccddeeff00112233
            addr := shr(96, data)
        }
    }

}
