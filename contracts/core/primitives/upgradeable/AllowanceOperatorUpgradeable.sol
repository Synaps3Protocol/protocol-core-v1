// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { LedgerUpgradeable } from "@synaps3/core/primitives/upgradeable/LedgerUpgradeable.sol";
import { IAllowanceOperator } from "@synaps3/core/interfaces/base/IAllowanceOperator.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

/// @title AllowanceOperatorUpgradeable
/// @dev Abstract contract for managing approvals, revocations, and collections with ledger tracking capabilities.
///      Provides core functionalities to handle allowances in an upgradeable system.
///      This contract integrates with the ledger system to record approvals and transactions.
abstract contract AllowanceOperatorUpgradeable is Initializable, LedgerUpgradeable, IAllowanceOperator {
    using FinancialOps for address;

    /// @custom:storage-location erc7201:allowanceoperatorupgradeable
    struct AllowanceOperatorStorage {
        /// @dev Holds the relation between approved funds, the currency, and amount
        mapping(bytes32 => mapping(address => uint256)) _approved;
    }

    /// @dev Storage slot for AllowanceOperatorUpgradeable, calculated using a unique namespace to avoid conflicts.
    /// The `ALLOWANCE_OPERATOR_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant ALLOWANCE_OPERATOR_SLOT =
        0xa8707513830ffbd3c47e0c83d1f5f0270db240ae37bb1f9a13f077f85b949c00;

    /// @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    /// This is the method to initialize this contract and any other extended contracts.
    /// slither-disable-next-line naming-convention
    function __AllowanceOperator_init() internal onlyInitializing {
        __Ledger_init();
    }

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    /// This is the method to initialize this contract as standalone.
    /// slither-disable-next-line naming-convention
    function __AllowanceOperator_init_unchained() internal onlyInitializing {}

    /// @notice Retrieves the approved balance for a specific relationship and currency.
    /// @param from The address of the account that granted the approval.
    /// @param to The address of the recipient for whom the approval was made.
    /// @param currency The address of the currency approved. Use `address(0)` for native tokens.
    /// @return The amount of funds approved by `from` for `to` in the specified `currency`.
    function getApprovedAmount(address from, address to, address currency) public view returns (uint256) {
        AllowanceOperatorStorage storage $ = _getAllowanceOperatorStorage();
        bytes32 relation = _computeComposedKey(from, to);
        return $._approved[relation][currency];
    }

    /// @notice Approves a specific amount of funds from the caller's balance for a recipient.
    /// @param to The address of the recipient for whom the funds are being approved.
    /// @param amount The amount of funds to approve.
    /// @param currency The address of the ERC20 token to approve. Use `address(0)` for native tokens.
    function approve(
        address to,
        uint256 amount,
        address currency
    ) public virtual onlyValidOperation(to, amount) returns (uint256) {
        _sumApprovedAmount(msg.sender, to, amount, currency);
        emit FundsApproved(msg.sender, to, amount, currency);
        return amount;
    }

    /// @notice Revokes the approved funds from the caller's balance for a specific recipient.
    /// @param to The address of the recipient whose approval is being revoked.
    /// @param currency The address of the ERC20 token associated with the approval. Use `address(0)` for native tokens.
    /// @return The amount of funds that were revoked from the approval.
    function revoke(
        address to,
        uint256 amount,
        address currency
    ) public virtual onlyValidOperation(to, amount) returns (uint256) {
        if (getApprovedAmount(msg.sender, to, currency) < amount) revert NoFundsToRevoke();
        _subApprovedAmount(msg.sender, to, amount, currency);
        emit FundsRevoked(msg.sender, to, amount, currency);
        return amount;
    }

    /// @notice Collects a specific amount of previously approved funds.
    /// @param from The address of the account from which the approved funds are being collected.
    /// @param amount The amount of funds to collect.
    /// @param currency The address of the ERC20 token to collect. Use `address(0)` for native tokens.
    function collect(
        address from,
        uint256 amount,
        address currency
    ) public virtual onlyValidOperation(from, amount) returns (uint256) {
        if (getApprovedAmount(from, msg.sender, currency) < amount) revert NoFundsToCollect(); //
        if (getLedgerBalance(from, currency) < amount) revert NoFundsToCollect(); // no balance

        _subApprovedAmount(from, msg.sender, amount, currency);
        _subLedgerEntry(from, amount, currency);
        _sumLedgerEntry(msg.sender, amount, currency);
        emit FundsCollected(from, msg.sender, amount, currency);
        return amount;
    }

    /// @notice Reduces the approved funds for a specific relationship and currency.
    /// @dev This function is called internally to subtract the amount from the approval mapping.
    /// @param from The address of the approver.
    /// @param to The address of the recipient.
    /// @param amount The amount to subtract from the approved funds.
    /// @param currency The currency in which the approval was made.
    function _subApprovedAmount(address from, address to, uint256 amount, address currency) private {
        AllowanceOperatorStorage storage $ = _getAllowanceOperatorStorage();
        bytes32 relation = _computeComposedKey(from, to);
        $._approved[relation][currency] -= amount;
    }

    /// @notice Increases the approved funds for a specific relationship and currency.
    /// @dev Adds the specified amount to the approved mapping for the given account pair and currency.
    /// @param from The address of the approver.
    /// @param to The address of the recipient.
    /// @param amount The amount to add to the approved funds.
    /// @param currency The currency in which the approval is being made.
    function _sumApprovedAmount(address from, address to, uint256 amount, address currency) private {
        AllowanceOperatorStorage storage $ = _getAllowanceOperatorStorage();
        bytes32 relation = _computeComposedKey(from, to);
        $._approved[relation][currency] += amount;
    }

    /// @notice Computes a unique key by combining two addresses.
    /// @dev This key is used to map relationships between accounts.
    /// @param from The address of the user for whom the key is being generated.
    /// @param to Encoded data representing the context for the operation.
    /// @return A `bytes32` hash that uniquely identifies the context-account pair.
    function _computeComposedKey(address from, address to) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, to));
    }

    /// @notice Internal function to get the allowance operator storage.
    /// @dev Uses assembly to retrieve the storage at the pre-calculated storage slot.
    function _getAllowanceOperatorStorage() private pure returns (AllowanceOperatorStorage storage $) {
        assembly {
            $.slot := ALLOWANCE_OPERATOR_SLOT
        }
    }
}
