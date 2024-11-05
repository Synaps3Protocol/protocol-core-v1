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

    /// @notice The keccak256 hash representing the governance role.
    /// @dev This constant is used to identify accounts with the admin permissions within the system.
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice The keccak256 hash representing the governance role.
    /// @dev This constant is used to identify accounts with the governance permissions within the system.
    bytes32 internal constant GOV_ROLE = keccak256("GOV_ROLE");
    /// @notice The keccak256 hash representing the moderator role.
    /// @dev This constant is used to identify accounts with the moderator permissions within the system.
    bytes32 internal constant MOD_ROLE = keccak256("MOD_ROLE");
    // This role is granted to any representant trusted account. eg: Verified Accounts, etc.
    bytes32 internal constant VERIFIED_ROLE = keccak256("VERIFIED_ROLE");

    bytes32 internal constant REFERENDUM_SUBMIT_TYPEHASH =
        keccak256("Submission(uint256 contentId, address initiator, uint256 nonce)");
}
