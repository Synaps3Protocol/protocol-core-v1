// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsAssetCustodian
/// @notice Interface for managing custodial rights of asset under the Rights Manager.
/// @dev This interface handles the retrieval and management of custodial records for content holders and distributors.
interface IRightsAssetCustodian {
    /// @notice Checks if the given distributor is a custodian for the specified content holder
    /// @param holder The address of the asset holder.
    /// @param distributor The address of the distributor to check.
    function isCustodian(address holder, address distributor) external view returns (bool);

    /// @notice Retrieves the custodians' addresses for a given content holder.
    /// @param holder The address of the asset rights holder whose custodians' addresses are being retrieved.
    function getCustodians(address holder) external view returns (address[] memory);

    /// @notice Retrieves the total number of asset items in custody for a given distributor.
    /// @param distributor The address of the distributor whose custodial content count is being requested.
    function getCustodyCount(address distributor) external returns (uint256);

    /// @notice Retrieves the custody records associated with a specific distributor.
    /// @param distributor The address of the distributor whose custody records are to be retrieved.
    function getCustodyRegistry(address distributor) external view returns (address[] memory);

    /// @notice Grants custodial rights over the asset held by a holder to a distributor.
    /// @param distributor The address of the distributor who will receive custodial rights.
    function grantCustody(address distributor) external;

    /// @notice Revokes custodial rights of a distributor for the caller's assets.
    /// @param distributor The distributor to revoke custody from.
    function revokeCustody(address distributor) external;
}
