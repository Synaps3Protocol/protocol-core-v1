// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IRightsAssetCustodianRegistrable
/// @notice Interface for registering and managing custodial rights over assets.
/// @dev This interface provides functions for granting and revoking custodial rights.
interface IRightsAssetCustodianRegistrable {
    /// @notice Assigns custodial rights over the caller's content to a specified custodian.
    /// @param custodian The address of the custodian to assign.
    function grantCustody(address custodian) external;

    /// @notice Revokes custodial rights of a custodian for the caller's assets.
    /// @param custodian The address of the custodian to revoke custody from.
    function revokeCustody(address custodian) external;
}
