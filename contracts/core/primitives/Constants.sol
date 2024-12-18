// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

library C {
    // We can not operate with float so we use base points instead..
    // If we need more precision we can adjust this bps..
    // https://en.wikipedia.org/wiki/Basis_point
    // 1 bps = 0.01, 10 bps = 0.1
    // ...
    uint8 internal constant SCALE_FACTOR = 100;
    uint16 internal constant BPS_MAX = 10_000;

    uint64 internal constant ADMIN_ROLE = 0; // alias type(uint64).min AccessManager
    uint64 internal constant GOV_ROLE = 1;
    uint64 internal constant MOD_ROLE = 2;
    uint64 internal constant VERIFIED_ROLE = 3;
    uint64 internal constant OPS_ROLE = 4;

    bytes32 internal constant REFERENDUM_SUBMIT_TYPEHASH =
        keccak256("Submission(uint256 assetId, address initiator, uint256 nonce)");
}
