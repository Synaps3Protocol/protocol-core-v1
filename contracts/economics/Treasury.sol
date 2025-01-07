// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { BalanceOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";

import { ITreasury } from "@synaps3/core/interfaces/economics/ITreasury.sol";
import { IFeesCollector } from "@synaps3/core/interfaces/economics/IFeesCollector.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title Treasury Contract
/// @dev This contract is designed to manage the storage and distribution of funds.
contract Treasury is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    BalanceOperatorUpgradeable,
    ITreasury
{
    using FinancialOps for address;
    using LoopOps for uint256;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __BalanceOperator_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    // TODO burn fees
    // TODO burn MMC only
    // TODO burn fees rate

    /// @notice Collects all accrued fees for a specified currency from a list of authorized collectors.
    /// @dev This function iterates over the list of collectors, requesting each to disburse their collected fees
    ///      for the given currency. The collected funds are credited to the treasury pool.
    /// @param collectors An array of addresses, each representing an authorized fee collector .
    /// @param currency The address of the ERC20 token for which fees are being collected.
    function collectFees(address[] calldata collectors, address currency) external restricted {
        uint256 collectorsLen = collectors.length;
        address pool = address(this); // fees pool is treasury
        uint256 totalCollected = 0;

        // For each collector, request the collected fees and add them to the treasury pool balance
        for (uint256 i = 0; i < collectorsLen; i = i.uncheckedInc()) {
            IFeesCollector collector = IFeesCollector(collectors[i]);
            uint256 collected = collector.disburse(currency);
            // register funds in treasury pool...
            _sumLedgerEntry(pool, collected, currency);
            emit FeesCollected(collectors[i], collected, currency);
            totalCollected += collected;
        }
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
