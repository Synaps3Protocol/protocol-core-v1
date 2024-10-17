// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.8.24/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ILedger } from "contracts/interfaces/ILedger.sol";

/// @title LedgerUpgradeable
/// @notice Abstract contract for managing accounts ledger that support upgradability.
abstract contract LedgerUpgradeable is Initializable, ILedger {
    /// @custom:storage-location erc7201:ledgerupgradeable
    /// @dev The LedgerStorage struct holds the ledger mapping.
    struct LedgerStorage {
        mapping(address => mapping(address => uint256)) _ledger;
    }

    /// @dev Storage slot for LedgerStorage, calculated using a unique namespace to avoid conflicts.
    /// The `LEDGER_SLOT` constant is used to point to the location of the storage.
    bytes32 private constant LEDGER_SLOT = 0xcb711bda070b7bbcc2b711ef3993cc17677144f4419b29e303bef375c5f40f00;

    /// @inheritdoc ILedger
    /// @notice Retrieves the ledger balance of an account for a specific currency.
    /// @param account The address of the account whose balance is being queried.
    /// @param currency The address of the currency to retrieve the balance for.
    function getLedgerBalance(address account, address currency) public view returns (uint256) {
        LedgerStorage storage $ = _getLedgerStorage();
        return $._ledger[account][currency];
    }

    /// @dev Initializes the contract and ensures it is upgradeable.
    /// Even if the initialization is harmless, this ensures the contract follows upgradeable contract patterns.
    function __Ledger_init() internal onlyInitializing {}

    /// @dev Function to initialize the contract without chaining, typically used in child contracts.
    function __Ledger_init_unchained() internal onlyInitializing {}

    /// @notice Internal function to set a ledger entry for an account in a specific currency.
    /// @param account The address of the account to set the ledger entry for.
    /// @param amount The amount to register for the account.
    /// @param currency The address of the currency being registered.
    /// @dev This function directly overwrites the existing ledger entry for the specified account and currency.
    function _setLedgerEntry(address account, uint256 amount, address currency) internal {
        LedgerStorage storage $ = _getLedgerStorage();
        $._ledger[account][currency] = amount;
    }

    /// @notice Internal function to accumulate currency fees for an account.
    /// @param account The address of the account to accumulate the ledger entry for.
    /// @param amount The amount to add to the existing ledger entry.
    /// @param currency The address of the currency being accumulated.
    /// @dev This function adds the amount to the current ledger entry for the specified account and currency.
    function _sumLedgerEntry(address account, uint256 amount, address currency) internal {
        LedgerStorage storage $ = _getLedgerStorage();
        $._ledger[account][currency] += amount;
    }

    /// @notice Internal function to subtract currency fees for an account.
    /// @param account The address of the account to subtract the ledger entry from.
    /// @param amount The amount to subtract from the existing ledger entry.
    /// @param currency The address of the currency being subtracted.
    /// @dev This function subtracts the amount from the current ledger entry for the specified account and currency.
    function _subLedgerEntry(address account, uint256 amount, address currency) internal {
        LedgerStorage storage $ = _getLedgerStorage();
        $._ledger[account][currency] -= amount;
    }

    /// @notice Internal function to get the ledger storage.
    /// @dev Uses assembly to retrieve the storage at the pre-calculated storage slot.
    function _getLedgerStorage() private pure returns (LedgerStorage storage $) {
        assembly {
            $.slot := LEDGER_SLOT
        }
    }
}
