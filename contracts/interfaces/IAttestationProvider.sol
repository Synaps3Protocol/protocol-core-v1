// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IAttestationProvider {
    /// @notice Returns the name of the attestor.
    /// @return The name of the attestor as a string.
    function name() external view returns (string memory);

    /// @notice Returns the address associated with the attestor.
    /// @return The address of the attestor.
    function getAddress() external view returns (address);

    /// @notice Creates a new attestation with the specified data.
    /// @param recipients The addresses of the recipients of the attestation.
    /// @param expireAt The timestamp at which the attestation will expire.
    /// @param data Additional data associated with the attestation.
    function attest(address[] calldata recipients, uint256 expireAt, bytes calldata data) external returns (uint256);

    /// @notice Verifies the validity of an attestation for a given attester and recipient.
    /// @param attester The address of the original creator of the attestation.
    /// @param recipient The address of the recipient whose attestation is being verified.
    function verify(address attester, address recipient) external view returns (bool);

    /// @notice Retrieves the attestation associated with a specific account and attester.
    /// @param recipient The address of the account involved in the attestation.
    /// @param attester The address of the original creator of the attestation.
    function getAttestation(address attester, address recipient) external view returns (uint256);
}
