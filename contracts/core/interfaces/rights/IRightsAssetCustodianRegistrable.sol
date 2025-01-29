// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsAssetCustodianRegistrable
/// @notice Interface for registering and managing custodial rights over assets.
/// @dev This interface provides functions for granting and revoking custodial rights.
interface IRightsAssetCustodianRegistrable {

    /// @notice Grants custodial rights over the asset held by a holder to a distributor.
    /// @dev Assigns the specified distributor as a custodian, allowing them to manage the holder's asset.
    /// @param distributor The address of the distributor who will receive custodial rights.
    function grantCustody(address distributor) external;

    /// @notice Revokes custodial rights of a distributor for the caller's assets.
    /// @dev Removes the specified distributor from the custody registry of the caller.
    /// @param distributor The address of the distributor to revoke custody from.
    function revokeCustody(address distributor) external;
}