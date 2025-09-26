// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { BalanceOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";

import { ITreasury } from "@synaps3/core/interfaces/economics/ITreasury.sol";
import { IFeesCollector } from "@synaps3/core/interfaces/economics/IFeesCollector.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title Treasury
/// @notice Manages the storage, distribution, and collection of protocol fees.
/// @dev Implements a restricted deposit system where only approved entities can interact.
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
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    // TODO burn fees
    // TODO burn MMC only
    // TODO burn fees rate

    // TODO after burn % distribute remaining fees to designated pools based on governance vote
    // function allocate(address pool, uint256 amount) restricted;
    // eg: proposal: deposit N fees to staking pool, deposit N fees to development pool, rewards, etc

    /// @notice Deposits a specified amount of currency into the treasury for a given recipient (pool).
    /// @dev Only whitelisted accounts (via `restricted`) can interact with this method.
    ///      This prevents arbitrary accounts from injecting funds into the treasury.
    /// @param pool The address of the pool credited with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit (use `address(0)` for native).
    /// @return The confirmed deposited amount.
    function deposit(
        address pool,
        uint256 amount,
        address currency
    ) external payable whenNotPaused restricted returns (uint256) {
        return _deposit(pool, amount, currency);
    }

    /// @notice Withdraws tokens from the treasury to a specified recipient.
    /// @dev Restricted to authorized accounts (via `restricted`).
    ///      Ensures treasury funds are only withdrawn under governance-approved flows.
    /// @param recipient The address receiving the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The token address for the withdrawal (use `address(0)` for native).
    /// @return The confirmed withdrawn amount.
    function withdraw(
        address recipient,
        uint256 amount,
        address currency
    ) external whenNotPaused restricted returns (uint256) {
        return _withdraw(recipient, amount, currency);
    }

    /// @notice Transfers tokens internally in the treasury ledger from the caller to a recipient.
    /// @dev Restricted to authorized accounts (via `restricted`).
    ///      Unlike `withdraw`, this does not move funds externally but shifts balances inside the ledger.
    /// @param recipient The address credited with the transfer.
    /// @param amount The amount to transfer.
    /// @param currency The token being transferred (use `address(0)` for native).
    /// @return The confirmed transferred amount.
    function transfer(
        address recipient,
        uint256 amount,
        address currency
    ) external whenNotPaused restricted returns (uint256) {
        return _transfer(recipient, amount, currency);
    }

    /// @notice Collects accrued fees for a specified currency from an authorized fee collector. (visitable)
    /// @dev This function requests the given collector to disburse its collected fees
    ///      for the specified currency. The collected funds are then credited to the treasury pool.
    ///      Only the governor can execute this function, ensuring controlled fee collection.
    /// @param amount The amount to collect from fee collector.
    /// @param currency The address of the ERC20 token for which fees are being collected.
    /// @param collector The address of an authorized fee collector.
    function collectFees(
        uint256 amount,
        address currency,
        address collector
    ) external restricted whenNotPaused nonReentrant {
        IFeesCollector feesCollector = IFeesCollector(collector);
        uint256 collected = feesCollector.disburse(amount, currency);
        _sumLedgerEntry(address(this), collected, currency);
        emit FeesCollected(collector, collected, currency);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
