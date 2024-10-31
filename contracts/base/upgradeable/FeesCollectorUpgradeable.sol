// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.8.24/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { LedgerUpgradeable } from "contracts/base/upgradeable/LedgerUpgradeable.sol";
import { IFeesCollector } from "contracts/interfaces/economics/IFeesCollector.sol";
import { TreasuryOps } from "contracts/libraries/TreasuryOps.sol";

/// @title FeesCollectorUpgradeable Contract
/// @notice Manages the address of the treasury and disburses collected funds in an upgradeable way.
/// @dev This is an abstract contract that implements the IFeesCollector interface.
abstract contract FeesCollectorUpgradeable is Initializable, LedgerUpgradeable, IFeesCollector {
    using TreasuryOps for address;

    /// @custom:storage-location erc7201:feescollectorupgradeable
    /// @notice Stores the treasury address used for disbursement operations.
    struct FeesCollectorStorage {
        address _treasury;
    }

    /// @dev Keccak-256 storage slot for the fees collector to avoid layout conflicts.
    ///      Namespaced storage layout helps prevent accidental overwrites in upgradeable contracts.
    bytes32 private constant FEES_COLLECTOR_SLOT = 0xad118695963461d59b4e186bb251fe176897e2c57f3362e8dade6f9a4f8e7400;

    /// @notice Error thrown when an invalid treasury address is provided.
    /// @param invalidAddress The invalid treasury address.
    error InvalidTreasuryAddress(address invalidAddress);

    /// @notice Error thrown when an unauthorized address attempts a disbursement.
    /// @param caller The unauthorized address attempting the disbursement.
    error InvalidUnauthorizedDisbursement(address caller);

    /// @dev Modifier to restrict access to the treasury.
    modifier onlyTreasury() {
        if (getTreasuryAddress() != msg.sender) {
            revert InvalidUnauthorizedDisbursement(msg.sender);
        }
        _;
    }

    /// @notice Returns the current address of the treasury.
    /// @return The address of the treasury.
    function getTreasuryAddress() public view returns (address) {
        FeesCollectorStorage storage $ = _getFeesCollectorStorage();
        return $._treasury;
    }

    /// @notice Disburses all collected funds of a specified currency from the contract to the treasury.
    /// @dev This function can only be called by the treasury. It transfers the full balance of the specified currency.
    /// @param currency The address of the ERC20 token to disburse.
    function disburse(address currency) external onlyTreasury returns (uint256) {
        // Transfer all funds of the specified currency to the treasury.
        address treasuryAddress = getTreasuryAddress();
        uint256 amount = getLedgerBalance(address(this), currency);
        if (amount == 0) return 0; // error trying transfer zero amount..
        // safe direct transfer to treasury address..
        treasuryAddress.transfer(amount, currency);
        emit FeesDisbursed(treasuryAddress, amount, currency);
        return amount;
    }

    /// @notice Initializes the fees collector with the specified treasury address.
    /// @dev This is part of the upgradeable pattern for initializing contract state.
    /// @param treasuryAddress The address of the treasury to initialize.
    function __FeesCollector_init(address treasuryAddress) internal onlyInitializing {
        __Ledger_init();
        __FeesCollector_init_unchained(treasuryAddress);
    }

    /// @notice Unchained initializer for the fees collector with the given treasury address.
    /// @dev Internal function for initializing the treasury address.
    /// @param treasuryAddress The address of the treasury.
    function __FeesCollector_init_unchained(address treasuryAddress) internal onlyInitializing {
        _setTreasuryAddress(treasuryAddress);
    }

    /// @notice Sets the address of the fees collector's treasury.
    /// @dev Internal function with validation to ensure the address is not zero.
    /// @param newFeesCollectorAddress The new address of the treasury.
    function _setTreasuryAddress(address newFeesCollectorAddress) internal {
        if (newFeesCollectorAddress == address(0)) revert InvalidTreasuryAddress(newFeesCollectorAddress);
        FeesCollectorStorage storage $ = _getFeesCollectorStorage();
        $._treasury = newFeesCollectorAddress;
    }

    /// @notice Accesses the fees collector's storage struct.
    /// @dev Uses assembly to directly reference the storage slot for the fees collector's treasury.
    /// @return $ The fees collector storage.
    function _getFeesCollectorStorage() private pure returns (FeesCollectorStorage storage $) {
        assembly {
            $.slot := FEES_COLLECTOR_SLOT
        }
    }
}
