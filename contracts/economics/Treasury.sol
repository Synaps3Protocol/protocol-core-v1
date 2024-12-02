// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";

import { IFeesCollector } from "@synaps3/core/interfaces/economics/IFeesCollector.sol";
import { ITreasury } from "@synaps3/core/interfaces/economics/ITreasury.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title Treasury Contract
/// @dev This contract is designed to manage the storage and distribution of funds.
contract Treasury is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    ITreasury
{
    using FinancialOps for address;
    using LoopOps for uint256;

    /// @notice Emitted when funds are disbursed to the treasury from a collector.
    /// @param collector The address of the collector disbursing the funds.
    /// @param amount The amount of tokens that were disbursed.
    /// @param currency The address of the ERC20 token contract for the currency disbursed.
    event FundsCollected(address indexed collector, uint256 amount, address currency);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Returns the contract's balance for the specified currency.
    /// @dev The function checks the balance for both native and ERC-20 tokens.
    /// @param currency The address of the currency to check the balance of.
    function getBalance(address currency) public view returns (uint256) {
        return address(this).balanceOf(currency);
    }

    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @dev This function withdraws funds from the caller's balance and transfers them to the recipient.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external nonReentrant restricted {
        if (getBalance(currency) < amount) revert NoFundsToWithdraw();
        recipient.transfer(amount, currency);
        emit FundsWithdrawn(recipient, amount, currency);
    }

    // TODO burn fees
    // TODO burn MMC only
    // TODO burn fees rate
    // TODO si habra mas que fees en el treasury deberia existir un registro? mas pools? 

    /// @notice Collects all accrued fees for a specified currency from a list of authorized collectors.
    /// @dev This function iterates over the list of collectors, requesting each to disburse their collected fees
    ///      for the given currency. The collected funds are credited to the treasury pool.
    /// @param collectors An array of addresses, each representing an authorized fee collector .
    /// @param currency The address of the ERC20 token for which fees are being collected.
    function collectFees(address[] calldata collectors, address currency) external restricted {
        uint256 collectorsLen = collectors.length;
        // For each collector, request the collected fees and add them to the treasury pool balance
        for (uint256 i = 0; i < collectorsLen; i = i.uncheckedInc()) {
            IFeesCollector collector = IFeesCollector(collectors[i]);
            uint256 collected = collector.disburse(currency);
            emit FundsCollected(collectors[i], collected, currency);
        }
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
