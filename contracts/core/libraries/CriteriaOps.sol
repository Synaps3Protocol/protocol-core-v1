// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title CriteriaOps
/// @notice Standard (de)serialization for policy criteria across core/periphery.
/// @dev Canonical shape: `criteria := abi.encode(uint8 kind, bytes value)`.
library CriteriaOps {
    /// @notice Encodes criteria with an address-type payload.
    /// @param kind The discriminant indicating the criterion type.
    /// @param addr The address payload (e.g. holder, group, etc.).
    /// @return criteria Canonical `(uint8 kind, bytes value)` encoding.
    function encode(uint256 kind, address addr) internal pure returns (bytes memory criteria) {
        return abi.encode(kind, abi.encode(addr));
    }

    /// @notice Encodes criteria with a uint256-type payload.
    /// @param kind The discriminant indicating the criterion type.
    /// @param id The numeric payload (e.g. assetId, tokenId, etc.).
    /// @return criteria Canonical `(uint8 kind, bytes value)` encoding.
    function encode(uint256 kind, uint256 id) internal pure returns (bytes memory criteria) {
        return abi.encode(kind, abi.encode(id));
    }

    /// @notice Encodes criteria with a bytes32-type payload.
    /// @param kind The discriminant indicating the criterion type.
    /// @param key The fixed-size 32-byte payload (e.g. collectionId, hashed key, etc.).
    /// @return criteria Canonical `(uint8 kind, bytes value)` encoding.
    function encode(uint256 kind, bytes32 key) internal pure returns (bytes memory criteria) {
        return abi.encode(kind, abi.encode(key));
    }

    /// @notice Decodes a canonical criteria blob into its discriminant and raw ABI-encoded value.
    /// @param criteria The canonical criteria blob to decode.
    /// @return kind The discriminant to interpret `value`.
    /// @return value The ABI-encoded payload; decode it further according to `kind`.
    function decode(bytes memory criteria) internal pure returns (uint256 kind, bytes memory value) {
        return abi.decode(criteria, (uint8, bytes));
    }
}
