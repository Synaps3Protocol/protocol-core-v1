// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title Type Definitions Library
/// @notice This library provides common type definitions for use in other contracts.
/// @dev This library defines types and structures that can be imported and used in other contracts.
library T {
    /// @title Scheme
    /// @notice Enum representing different fee calculation schemes in the protocol.
    /// Each scheme determines how fees are computed based on the operation's context.
    /// Examples include flat amounts, percentages, or basis points (BPS).
    enum Scheme {
        __, // Undefined or default value
        FLAT, // Flat fee: a fixed amount, independent of transaction value
        NOMINAL, // Nominal fee: a percentage of the transaction value (e.g., 5%)
        BPS // Basis points: fractional fee, where 1 BPS = 0.01% (e.g., 100 BPS = 1%)
    }

    /// @title Cipher
    /// @notice Enum representing available encryption methods.
    /// @dev Covers traditional encryption schemes and decentralized key management systems.
    enum Cipher {
        __, // Undefined or default state
        LIT, // Decentralized threshold encryption
        RSA, // Asymmetric encryption (public/private key)
        EC // Elliptic Curve cryptography
    }

    /// @title Agreement
    /// @dev Represents an agreement between multiple parties regarding the distribution and management of asset.
    /// @notice This struct captures the total amount involved, net amount after deductions, distribution fees,
    /// and the relevant addresses involved in the agreement.
    struct Agreement {
        address arbiter; // the designated escrow agent enforcing the agreement.
        address currency; // the currency used in transaction
        address initiator; // the initiator of the transaction
        uint256 total; // the transaction total amount
        uint256 fees; // the agreement protocol fees
        address[] parties; // the accounts related to agreement
        bytes payload; // any additional data needed during agreement execution
    }

    /// @title TimeFrame
    /// @notice Enum representing the time frame for calculations or actions.
    enum TimeFrame {
        NONE, // Default value indicating "unset" or "no limit"
        HOURLY, // Indicates a rate basis of per hour
        DAILY, // Indicates a rate basis of per day
        MONTHLY // Indicates a rate basis of per month
    }

    /// @title Terms
    /// @notice Represents the financial and contractual terms associated with a specific policy or agreement.
    /// @dev This struct is used to capture both on-chain and off-chain terms for content or agreement management.
    ///      It includes fields for currency, amount, rate basis, calculation formula, and off-chain terms.
    struct Terms {
        uint256 amount; // The rate amount based on the rate basis, expressed in the smallest unit of the currency
        address currency; // The currency in which the amount is denominated, e.g., MMC 
        TimeFrame timeFrame; // The time frame for the amount, using a standardized enum (e.g., HOURLY, DAILY)
        string uri; // URI pointing to off-chain terms for additional details or extended documentation 
        // TODO we could extend the terms based on the real needs ..
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
