// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { BalanceOperatorUpgradeable } from "@synaps3/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";

import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

/// @title Treasury Contract
/// @dev This contract is designed to manage the storage and distribution of funds.
contract TokenVault is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    BalanceOperatorUpgradeable
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
        __BalanceOperator_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Deposits a specified amount of currency into the pool for a given recipient.
    /// @param recipient The address of the account to credit with the deposit.
    /// @param amount The amount of currency to deposit.
    /// @param currency The address of the ERC20 token to deposit.
    function deposit(address recipient, uint256 amount, address currency) external {
        uint256 confirmed = _deposit(recipient, amount, currency);
        emit FundsDeposited(recipient, confirmed, currency);
    }

    // TODO withdraw speed bump time lock
    /// @notice Withdraws tokens from the contract to a specified recipient's address.
    /// @dev This function withdraws funds from the caller's balance and transfers them to the recipient.
    /// @param recipient The address that will receive the withdrawn tokens.
    /// @param amount The amount of tokens to withdraw.
    /// @param currency The currency to associate fees with. Use address(0) for the native coin.
    function withdraw(address recipient, uint256 amount, address currency) external nonReentrant {
        uint256 confirmed = _withdraw(recipient, amount, currency);
        emit FundsWithdrawn(recipient, confirmed, currency);
    }

    /// @notice Transfers a specified amount of currency from the caller's balance to a given recipient.
    /// @dev Ensures the caller has sufficient balance before performing the transfer. Updates the ledger accordingly.
    /// @param recipient The address of the account to credit with the transfer.
    /// @param amount The amount of currency to transfer.
    /// @param currency The address of the ERC20 token to transfer. Use `address(0)` for native tokens.
    function transfer(address recipient, uint256 amount, address currency) external nonReentrant {
        uint256 confirmed = _transfer(recipient, amount, currency);
        emit FundsTransferred(msg.sender, recipient, confirmed, currency);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
