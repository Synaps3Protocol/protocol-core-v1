// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { BalanceOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";

import { ITreasury } from "@synaps3/core/interfaces/economics/ITreasury.sol";
import { IFeesCollector } from "@synaps3/core/interfaces/economics/IFeesCollector.sol";
import { IBalanceDepositor } from "@synaps3/core/interfaces/base/IBalanceDepositor.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title Treasury
/// @notice Manages the storage, distribution, and collection of protocol fees.
/// @dev Implements a restricted deposit system where only approved entities can interact.
contract Treasury is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    BalanceOperatorUpgradeable,
    ITreasury
{
    using FinancialOps for address;
    using LoopOps for uint256;

    /// @notice Emitted when funds are disbursed to the treasury from a collector.
    /// @param collector The address of the collector disbursing the funds.
    /// @param amount The amount of tokens that were disbursed.
    /// @param currency The address of the ERC20 token contract for the currency disbursed.
    event FeesCollected(address indexed collector, uint256 amount, address currency);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __BalanceOperator_init();
        __AccessControlled_init(accessManager);
    }

    // TODO burn fees
    // TODO burn MMC only
    // TODO burn fees rate

    // TODO after burn % distribute remaining fees to designated pools based on governance vote
    // function allocate(address pool, uint256 amount) restricted;
    // eg: proposal: deposit N fees to staking pool, deposit N fees to development pool, rewards, etc

    /// @notice Deposits a specified amount of currency into the treasury for a given recipient.
    /// @param pool The address of the pool to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(
        address pool,
        uint256 amount,
        address currency
    ) public override(BalanceOperatorUpgradeable, IBalanceDepositor) restricted returns (uint256) {
        // restricted deposit to avoid invalid operations
        // only allowed accounts can interact with this method
        return super.deposit(pool, amount, currency);
    }

    /// @notice Collects accrued fees for a specified currency from an authorized fee collector. (visitable)
    /// @dev This function requests the given collector to disburse its collected fees
    ///      for the specified currency. The collected funds are then credited to the treasury pool.
    ///      Only the governor can execute this function, ensuring controlled fee collection.
    /// @param collector The address of an authorized fee collector.
    /// @param currency The address of the ERC20 token for which fees are being collected.
    function collectFees(address collector, address currency) external restricted nonReentrant {
        IFeesCollector feesCollector = IFeesCollector(collector);
        uint256 collected = feesCollector.disburse(currency);
        _sumLedgerEntry(address(this), collected, currency);
        emit FeesCollected(collector, collected, currency);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
