// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity ^0.8.24;

import "./IFeesManager.sol";
import "./ICurrencyManager.sol";

interface IDistributor  {
    /// @notice Set the endpoint of the distributor.
    /// @dev This function can only be called by the owner of the contract.
    /// @param _endpoint The new distributor's endpoint.
    function setEndpoint(string memory _endpoint) external;

    /// @notice Retrieves the endpoint of the distributor.
    /// @dev This function allows users to view the current endpoint of the distributor.
    /// @return The current endpoint of the distributor.
    function getEndpoint() external view returns (string memory);

    /// @notice Retrieves the manager of the distributor.
    /// @dev This function allows users to view the current manager of the distributor.
    /// @return The address of the current manager of the distributor.
    function getManager() external view returns (address);
}
