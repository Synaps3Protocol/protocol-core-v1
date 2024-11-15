// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title Type Definitions Library
/// @notice This library provides common type definitions for use in other contracts.
/// @dev This library defines types and structures that can be imported and used in other contracts.
library T {
    /// @title Context
    /// @notice Enum to represent different operational contexts within the protocol.
    /// Depending on the context, different logic or parameters may apply.
    /// eg: Fees are set based on the context of the protocol operation.
    enum Context {
        __,
        SYN, // Syndication context
        RMA // Rights Management Agreement
    }

    /// @title VaultType
    /// @notice Enum representing the different access or cryptographic methods available.
    /// This enum covers traditional cryptographic algorithms as well as decentralized key
    /// and access management systems.
    enum VaultType {
        __,
        LIT,
        RSA,
        EC
    }

    /// @title Agreement
    /// @dev Represents an agreement between multiple parties regarding the distribution and management of asset.
    /// @notice This struct captures the total amount involved, net amount after deductions, distribution fees,
    /// and the relevant addresses involved in the agreement.
    struct Agreement {
        bool active; // the agreement status
        address broker; // the authorized account to manage the agreement.
        address currency; // the currency used in transaction
        address initiator; // the initiator of the transaction
        uint256 createdAt; // the agreement creation date
        uint256 amount; // the transaction total amount
        uint256 fees; // the agreement protocol fees
        uint256 available; // the remaining amount after fees
        address[] parties; // the accounts related to agreement
        bytes payload; // any additional data needed during agreement execution
    }

    /// @title Setup
    /// @dev Represents a setup process for initializing and authorizing a policy contract for content.
    struct Setup {
        address holder; // the asset rights holder
        bytes payload; // any additional data needed during setup execution
    }

    /// @title RateBasis
    /// @notice Enum representing different time bases for calculating terms or fees.
    /// @dev Includes options for unset none, hourly, daily, monthly, and yearly bases.
    enum RateBasis {
        NONE, // Default value indicating "unset" or "not specified"
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
        address currency; // The currency in which the amount is denominated, e.g., ETH or USDC
        RateBasis rateBasis; // The time basis for the amount, using a standardized enum (e.g., HOURLY, DAILY)
        string uri; // URI pointing to off-chain terms for additional details or extended documentation
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
