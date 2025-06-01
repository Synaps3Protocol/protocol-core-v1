// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title ICustodian
/// @notice Interface for custodian contracts responsible for managing content custody.
interface ICustodian {
    /// @notice Set the endpoint of the custodian.
    /// @dev This function can only be called by the owner of the contract.
    /// @param _endpoint The new custodian's endpoint.
    function setEndpoint(string calldata _endpoint) external;

    /// @notice Retrieves the endpoint of the custodian.
    /// @dev This function allows users to view the current endpoint of the custodian.
    function getEndpoint() external view returns (string memory);

    /// @notice Retrieves the manager of the custodian.
    /// @dev This function allows users to view the current manager of the custodian.
    function getManager() external view returns (address);
}
