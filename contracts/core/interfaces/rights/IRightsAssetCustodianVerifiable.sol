// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IRightsAssetCustodianVerifiable
/// @notice Interface for verifying and retrieving custody-related data.
/// @dev This interface provides read-access functions to check custodianship status and custody records.
interface IRightsAssetCustodianVerifiable {
    /// @notice Checks if a given distributor is a custodian for the specified content holder.
    /// @dev Returns true if the distributor has custodial rights over the holder's assets.
    /// @param holder The address of the asset rights holder.
    /// @param distributor The address of the distributor to check.
    /// @return True if the distributor is a custodian, false otherwise.
    function isCustodian(address holder, address distributor) external view returns (bool);

    /// @notice Retrieves the addresses of all custodians assigned to a given content holder.
    /// @dev Returns an array of addresses representing custodians for the specified asset holder.
    /// @param holder The address of the asset rights holder whose custodians are being retrieved.
    /// @return An array of addresses of assigned custodians.
    function getCustodians(address holder) external view returns (address[] memory);

    /// @notice Retrieves the total number of asset items in custody for a given distributor.
    /// @dev Returns the number of assets managed by the specified distributor.
    /// @param distributor The address of the distributor whose custodial content count is being requested.
    /// @return The total number of assets held in custody by the distributor.
    function getCustodyCount(address distributor) external view returns (uint256);
}
