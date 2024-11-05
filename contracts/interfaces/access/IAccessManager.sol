// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

interface IAccessManager is IAccessControl {
    /// @notice Returns the current governor address.
    /// @return The address of the current governor.
    function getGovernor() external view returns (address);

    /// @notice Sets the governance address.
    /// @param governor The address to set as the new governor.
    function setGovernor(address governor) external;
}
