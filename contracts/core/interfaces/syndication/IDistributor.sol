// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IBalanceVerifiable } from "contracts/core/interfaces/IBalanceVerifiable.sol";
import { IBalanceWithdrawable } from "contracts/core/interfaces/IBalanceWithdrawable.sol";

interface IDistributor is IBalanceVerifiable, IBalanceWithdrawable {
    /// @notice Set the endpoint of the distributor.
    /// @dev This function can only be called by the owner of the contract.
    /// @param _endpoint The new distributor's endpoint.
    function setEndpoint(string calldata _endpoint) external;

    /// @notice Retrieves the endpoint of the distributor.
    /// @dev This function allows users to view the current endpoint of the distributor.
    function getEndpoint() external view returns (string memory);

    /// @notice Retrieves the manager of the distributor.
    /// @dev This function allows users to view the current manager of the distributor.
    function getManager() external view returns (address);
}
