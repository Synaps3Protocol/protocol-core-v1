// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { LedgerUpgradeable } from "@synaps3/core/primitives/upgradeable/LedgerUpgradeable.sol";

import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title Treasury Contract
/// @dev This contract is designed to manage the storage and distribution of funds.
contract TokenVault is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    LedgerUpgradeable,
    ILedgerVault
{
    using FinancialOps for address;

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

    /// @notice Deposits a specified amount of currency into the treasury for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address recipient, uint256 amount, address currency) external {
        uint256 confirmed = msg.sender.safeDeposit(amount, currency);
        _sumLedgerEntry(recipient, confirmed, currency);
        emit FundsDeposited(recipient, confirmed, currency);
    }

    // TODO withdraw speed bump time lock
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

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
