// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IRightsAssetCustodianVerifiable
/// @notice Interface for verifying custodian assignments and querying custody-related data.
interface IRightsAssetCustodianVerifiable {
    /// @notice Checks whether a custodian is currently assigned to a holder.
    /// @dev Returns true only if the custodian is active and listed for the specified holder.
    /// @param custodian The address of the custodian to verify.
    /// @param holder The address of the asset rights holder.
    /// @return True if `custodian` is valid and assigned to `holder`, false otherwise.
    function isCustodian(address custodian, address holder) external view returns (bool);
}
