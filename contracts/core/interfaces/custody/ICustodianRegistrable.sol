// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title ICustodianRegistrable
/// @dev Interface for managing custodians registration.
interface ICustodianRegistrable {
    /// @notice Registers data with a given identifier.
    /// @param custodian The address of the custodian to register.
    /// @param currency The currency used to pay enrollment.
    function register(address custodian, address currency) external;

    /// @notice Approves the data associated with the given identifier.
    /// @param custodian The address of the custodian to approve.
    function approve(address custodian) external;

    /// @notice Revokes the registration of an entity.
    /// @param custodian The address of the custodian to revoke.
    function revoke(address custodian) external;

    /// @notice Retrieves the enrollment deadline for a custodian.
    /// @param custodian The address of the custodian.
    function getEnrollmentDeadline(address custodian) external view returns (uint256);

    /// @notice Retrieves the total number of enrollments.
    function getEnrollmentCount() external view returns (uint256);
}
