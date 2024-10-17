// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IBalanceVerifiable } from "contracts/interfaces/IBalanceVerifiable.sol";
import { IBalanceWithdrawable } from "contracts/interfaces/IBalanceWithdrawable.sol";

/// @title ITreasury Interface
/// @notice Defines the standard functions for a Treasury contract.
interface ITreasury is IBalanceVerifiable, IBalanceWithdrawable {
    /// @notice Retrieves the vault address where operational funds or profits are stored.
    /// @dev This address points to the vault responsible for managing protocol-level profits.
    ///      Funds stored here are typically for operational purposes or governance management.
    function getVaultAddress() external view returns (address);

    /// @notice Retrieves the pool address where global user funds are held.
    /// @dev This address is dedicated to managing user deposits, rewards, or other pooled assets.
    ///      It helps in segregating protocol profits from user-related funds.
    function getPoolAddress() external view returns (address);
}
