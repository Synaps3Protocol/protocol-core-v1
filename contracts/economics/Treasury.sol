// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { LedgerUpgradeable } from "contracts/base/upgradeable/LedgerUpgradeable.sol";

import { IFeesCollector } from "contracts/interfaces/economics/IFeesCollector.sol";
import { ITreasury } from "contracts/interfaces/economics/ITreasury.sol";
import { TreasuryOps } from "contracts/libraries/TreasuryOps.sol";

// TODO payment splitter
// TODO aca se puede tener un metodo que collecte todos los fees
// https://docs.openzeppelin.com/contracts/4.x/api/finance#PaymentSplitter

/// @title Treasury Contract
/// @dev This contract is designed to manage the storage and distribution of funds.
contract Treasury is
    Initializable,
    UUPSUpgradeable,
    GovernableUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    LedgerUpgradeable,
    ITreasury
{
    using TreasuryOps for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
        __ReentrancyGuardTransient_init();
    }

    /// @notice Deposits a specified amount of currency into the treasury for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address recipient, uint256 amount, address currency) external {
        uint256 confirmed = msg.sender.safeDeposit(amount, currency);
        _sumLedgerEntry(recipient, confirmed, currency);
        emit FundsDeposited(recipient, confirmed, currency);
    }

    // TODO withdraw con con speed bump time lock
    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @dev This function withdraws funds from the caller's balance and transfers them to the recipient.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external nonReentrant {
        if (getLedgerBalance(msg.sender, currency) < amount) revert NoFundsToWithdraw();
        _subLedgerEntry(msg.sender, amount, currency);
        recipient.transfer(amount, currency);
        emit FundsWithdrawn(recipient, amount, currency);
    }

    // TODO burn fees
    // TODO burn fees rate

    /// @notice Collects all accrued fees for a specified currency from a list of authorized collectors.
    /// @dev This function iterates over the list of collectors, requesting each to disburse their collected fees
    ///      for the given currency. The collected funds are credited to the treasury pool.
    /// @param collectors An array of addresses, each representing an authorized fee collector .
    /// @param currency The address of the ERC20 token for which fees are being collected.
    function collectFees(address[] calldata collectors, address currency) external onlyAdmin {
        uint256 collectorsLen = collectors.length;
        address pool = address(this);

        // For each collector, request the collected fees and add them to the treasury pool balance
        for (uint256 i = 0; i < collectorsLen; i++) {
            IFeesCollector collector = IFeesCollector(collectors[i]);
            uint256 collected = collector.disburse(currency);
            // register funds in treasury pool...
            _sumLedgerEntry(pool, collected, currency);
            emit FundsCollected(collectors[i], collected, currency);
        }
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
