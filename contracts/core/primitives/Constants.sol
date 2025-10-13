// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

library C {
    // We can not operate with float so we use base points instead..
    // If we need more precision we can adjust this bps..
    // https://en.wikipedia.org/wiki/Basis_point
    // 1 bps = 0.01, 10 bps = 0.1
    // ...
    uint256 internal constant SCALE_FACTOR = 100;
    uint256 internal constant BPS_MAX = 10_000;

    // Criteria provide a standardized, compact (kind, value) reference to identify the resource or context to which a policy applies.
    // The protocol’s core treats criteria as opaque data, while external components interpret the semantics.
    // This abstraction unifies enforcement, access verification, and term resolution under a single interface, enabling extensibility
    // and interoperability across policies and resource types without altering the core.
    /// @notice Criterion based on the rights holder (e.g., the content owner).
    /// @dev Encoded as `uint256` value `0`.
    uint256 internal constant HOLDER_CRITERIA = 0;
    /// @notice Criterion based on a specific asset, identified by its unique ID.
    /// @dev Encoded as `uint256` value `1`.
    uint256 internal constant ASSET_CRITERIA = 1;

    uint64 internal constant ADMIN_ROLE = 0; // alias type(uint64).min AccessManager
    uint64 internal constant GOV_ROLE = 1; // governance role
    uint64 internal constant OPS_ROLE = 2; // operations roles
    uint64 internal constant VER_ROLE = 3; // account verified role
    uint64 internal constant SEC_ROLE = 4; // protocol security council
    uint64 internal constant TREASURER_ROLE = 5; // protocol treasurer

    uint64 internal constant CONTENT_COUNCIL_ROLE = 6; // content validation/curation roles
    uint64 internal constant CUSTODY_COUNCIL_ROLE = 7; // nodes validations roles

    bytes32 internal constant REFERENDUM_SUBMIT_TYPEHASH =
        keccak256("Submission(uint256 assetId, address initiator, uint256 nonce)");
}
