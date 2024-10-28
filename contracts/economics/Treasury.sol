// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { ITreasury } from "contracts/interfaces/economics/ITreasury.sol";

// TODO payment splitter
// https://docs.openzeppelin.com/contracts/4.x/api/finance#PaymentSplitter

/// @title Treasury Contract
/// @dev This contract is designed to manage the storage and distribution of funds.
contract Treasury is Initializable, UUPSUpgradeable, GovernableUpgradeable, ITreasury {
    address public vaultAddress;
    address public poolAddress;

    /// @notice Initializes the Treasury contract by setting default addresses for the vault and pool.
    /// @dev Should be called only once during deployment.
    function initialize() public initializer {
        vaultAddress = address(this);
        poolAddress = vaultAddress;
    }

    /// @notice Sets a new pool address. Restricted to governance.
    /// @param poolAddress_ The new address to be set as the pool.
    function setPoolAddress(address poolAddress_) external onlyGov {
        // TODO cambiar a revert
        // require(poolAddress_ != address(0), "Invalid pool address");
        poolAddress = poolAddress_;
    }

    /// @notice Sets a new vault address. Restricted to governance.
    /// @param vaultAddress_ The new address to be set as the vault.
    function setVaultAddress(address vaultAddress_) external onlyGov {
        // TODO cambiar a revert
        // require(vaultAddress_ != address(0), "Invalid vault address");
        vaultAddress = vaultAddress_;
    }

    /// @notice Retrieves the pool address.
    function getPoolAddress() public view returns (address) {
        return poolAddress;
    }

    /// @notice Retrieves the vault address.
    function getVaultAddress() public view returns (address) {
        return vaultAddress;
    }

    /// @notice Withdraws a specific amount of currency to a recipient.
    /// @param recipient The address receiving the withdrawal.
    /// @param amount The amount to be withdrawn.
    /// @param currency The currency being withdrawn.
    function withdraw(address recipient, uint256 amount, address currency) public {}

    /// @notice Retrieves the balance of a specific currency held by the Treasury.
    /// @param currency The address of the currency to query.
    function getBalance(address currency) external view returns (uint256) {}

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
