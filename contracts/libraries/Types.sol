// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title Type Definitions Library
/// @notice This library provides common type definitions for use in other contracts.
/// @dev This library defines types and structures that can be imported and used in other contracts.
library T {
    /// @notice Enum to represent different operational contexts within the protocol.
    /// Depending on the context, different logic or parameters may apply.
    enum Context {
        __, // Undefined type, default state for uninitialized or invalid contexts.
        SYN, // Syndication context
        RMA // Rights Management Agreement
    }

    /// @title Agreement
    /// @dev Represents an agreement between multiple parties regarding the distribution and management of content.
    /// @notice This struct captures the total amount involved, net amount after deductions, distribution fees,
    /// and the relevant addresses involved in the agreement.
    struct Agreement {
        uint256 time; // the agreement creation date
        uint256 total; // the transaction total amount
        uint256 available; // the remaining amount after fees
        address currency; // the currency used in transaction
        address account; // the account related to agreement
        address holder; // the content rights holder
        bytes payload; // any additional data needed during agreement execution
        bool active; // the agreement status
    }

    /// @title Setup
    /// @dev Represents a setup process for initializing and authorizing a policy contract for content.
    struct Setup {
        address holder; // the content rights holder
        bytes payload; // any additional data needed during setup execution
    }

    /// @title Terms
    /// @notice Represents the financial and contractual terms associated with a specific policy or agreement.
    /// @dev This struct is used to capture both on-chain and off-chain terms for content or agreement management.
    struct Terms {
        address currency;
        uint256 amount;
        string uri; // off-chain terms
    }

    /// @notice A struct containing the necessary information to reconstruct an EIP-712 typed data signature.
    /// @dev We could use this information to handle signature logic with delegated actions from the account owner.
    /// @param v The signature's recovery parameter.
    /// @param r The signature's r parameter.
    /// @param s The signature's s parameter.
    /// @param signer The address of the signer. Needed as a parameter to support EIP-1271.
    struct EIP712Signature {
        uint8 v; // 1 byte
        bytes32 r; // 32 bytes
        bytes32 s; // 32 bytes
        address signer;
    }
}
