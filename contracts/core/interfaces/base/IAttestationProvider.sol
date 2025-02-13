// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

/// @title IAttestationProvider
/// @notice Interface for managing attestations, including their creation, retrieval, and verification.
/// @dev Implementing contracts are expected to provide mechanisms to generate, store, and validate attestations.
interface IAttestationProvider {
    /// @notice Returns the name of the attestor.
    /// @return The name of the attestor as a string.
    function getName() external view returns (string memory);

    /// @notice Returns the address associated with the attestor.
    /// @return The address of the attestor.
    function getAddress() external view returns (address);

    /// @notice Creates a new attestation with the specified data.
    /// @param recipients The addresses of the recipients of the attestation.
    /// @param expireAt The timestamp at which the attestation will expire.
    /// @param data Additional data associated with the attestation.
    function attest(
        address[] calldata recipients,
        uint256 expireAt,
        bytes calldata data
    ) external returns (uint256[] memory);

    /// @notice Verifies the validity of an attestation for a given attester and recipient.
    /// @param attestationId The id of the attestation to verify.
    /// @param recipient The address of the recipient whose attestation is being verified.
    function verify(uint256 attestationId, address recipient) external view returns (bool);
}
