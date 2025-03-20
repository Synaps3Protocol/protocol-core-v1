// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IRightsAssetCustodianRegistrable
/// @notice Interface for registering and managing custodial rights over assets.
/// @dev This interface provides functions for granting and revoking custodial rights.
interface IRightsAssetCustodianRegistrable {
    /// @notice Grants custodial rights over the asset held by a holder to a custodian.
    /// @dev Assigns the specified custodian as a custodian, allowing them to manage the holder's asset.
    /// @param custodian The address of the custodian who will receive custodial rights.
    function grantCustody(address custodian) external;

    /// @notice Revokes custodial rights of a custodian for the caller's assets.
    /// @dev Removes the specified custodian from the custody registry of the caller.
    /// @param custodian The address of the custodian to revoke custody from.
    function revokeCustody(address custodian) external;
}
