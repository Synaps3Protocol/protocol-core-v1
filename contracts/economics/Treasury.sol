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
/// @dev This contract is designed to manage funds and token transfers,
/// and it implements upgradeable features using UUPS proxy pattern.
contract Treasury is Initializable, UUPSUpgradeable, GovernableUpgradeable, ITreasury {
    address public vaultAddress;
    address public poolAddress;

    function initialize() public initializer {
        vaultAddress = address(this);
        poolAddress = address(this);
    }

    // Getter function to return the vault address
    function getPoolAddress() public view returns (address) {
        return poolAddress;
    }

    // Function to set the vault address (for governance/admin use)
    function setPoolAddress(address poolAddress_) external onlyGov {
        // TODO cambiar a revert
        // require(_vaultAddress != address(0), "Invalid vault address");
        poolAddress = poolAddress_;
    }

    // Function to set the vault address (for governance/admin use)
    function setVaultAddress(address vaultAddress_) external onlyGov {
        // TODO cambiar a revert
        // require(_vaultAddress != address(0), "Invalid vault address");
        vaultAddress = vaultAddress_;
    }

    // Getter function to return the vault address
    function getVaultAddress() public view returns (address) {
        return vaultAddress;
    }

    function withdraw(address recipient, uint256 amount, address currency) public onlyGov {}

    function getBalance(address currency) external view returns (uint256) {}

    // withdraw
    // etc..

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
