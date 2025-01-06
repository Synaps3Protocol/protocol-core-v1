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

    /// @notice Deposits a specified amount of currency into the ledger of the specified pool.
    /// @param pool The address of the pool to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address pool, uint256 amount, address currency) external returns (uint256) {
        uint256 confirmed = _deposit(pool, amount, currency);
        emit FundsDeposited(pool, msg.sender, confirmed, currency);
        return confirmed;
    }

    /// @notice Transfers a specified amount of currency from the caller pool's balance to a given pool.
    /// @dev Ensures the caller has sufficient balance before performing the transfer.
    /// @param pool The address of the pool to credit with the transfer.
    /// @param amount The amount of currency to transfer.
    /// @param currency The address of the ERC20 token to transfer. Use `address(0)` for native tokens.
    function transfer(address pool, uint256 amount, address currency) external nonReentrant returns (uint256) {
        uint256 confirmed = _transfer(pool, amount, currency);
        emit FundsTransferred(msg.sender, pool, confirmed, currency);
        return confirmed;
    }

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @dev This function withdraws funds from the caller's balance and transfers them to the recipient.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external nonReentrant returns (uint256) {
        uint256 confirmed = _withdraw(recipient, amount, currency);
        emit FundsWithdrawn(recipient, msg.sender, confirmed, currency);
        return confirmed;
    }

    /// @notice Reserves a specific amount of funds from the caller's balance for a recipient.
    /// @param to The address of the recipient for whom the funds are being reserved.
    /// @param amount The amount of funds to reserve.
    /// @param currency The address of the ERC20 token to reserve. Use `address(0)` for native tokens.
    function reserve(address to, uint256 amount, address currency) external returns (uint256) {
        uint256 confirmed = _reserve(to, amount, currency);
        emit FundsReserved(msg.sender, to, confirmed, currency);
        return amount;
    }

    /// @notice Collects a specific amount of previously reserved funds.
    /// @param from The address of the account from which the reserved funds are being collected.
    /// @param amount The amount of funds to collect.
    /// @param currency The address of the ERC20 token to collect. Use `address(0)` for native tokens.
    function collect(address from, uint256 amount, address currency) external returns (uint256) {
        uint256 confirmed = _collect(from, amount, currency);
        emit FundsCollected(from, msg.sender, confirmed, currency);
        return amount;
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
