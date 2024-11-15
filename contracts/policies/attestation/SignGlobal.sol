// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ISP } from "@ethsign/sign-protocol-evm/src/interfaces/ISP.sol";
import { Attestation } from "@ethsign/sign-protocol-evm/src/models/Attestation.sol";
import { DataLocation } from "@ethsign/sign-protocol-evm/src/models/DataLocation.sol";
import { IAttestationProvider } from "contracts/core/interfaces/IAttestationProvider.sol";
import { LoopOps } from "contracts/core/libraries/LoopOps.sol";

contract SignGlobal is IAttestationProvider {
    using LoopOps for uint256;

    ISP public immutable SPI_INSTANCE;
    uint64 public immutable SCHEMA_ID;

    constructor(address spiAddress, uint64 schemaId) {
        SPI_INSTANCE = ISP(spiAddress);
        SCHEMA_ID = schemaId;
    }

    /// @notice Returns the name of the attestor.
    /// @return The name of the attestor as a string.
    function getName() public pure returns (string memory) {
        return "SignGlobal";
    }

    /// @notice Returns the address associated with the attestor.
    /// @return The address of the attestor.
    function getAddress() public view returns (address) {
        return address(SPI_INSTANCE);
    }

    /// @notice Creates a new attestation with the specified data.
    /// @param recipients The addresses of the recipients of the attestation.
    /// @param expireAt The timestamp at which the attestation will expire.
    /// @param data Additional data associated with the attestation.
    function attest(address[] calldata recipients, uint256 expireAt, bytes calldata data) external returns (uint256) {
        Attestation memory a = Attestation({
            schemaId: SCHEMA_ID,
            attester: address(this),
            attestTimestamp: 0,
            revokeTimestamp: 0,
            linkedAttestationId: 0,
            validUntil: uint64(expireAt),
            dataLocation: DataLocation.ONCHAIN,
            recipients: _convertAddressesToBytes(recipients),
            revoked: false,
            data: data
        });

        // Call the SPI instance to register the attestation in the system
        // SPI_INSTANCE.attest() stores the attestation and returns an ID for tracking
        return SPI_INSTANCE.attest(a, "", "", "");
    }

    /// @notice Verifies the validity of an attestation for a given attester and recipient.
    /// @param attestationId The id of the attestation to verify.
    /// @param recipient The address of the recipient whose attestation is being verified.
    function verify(uint256 attestationId, address recipient) external view returns (bool) {
        // check attestation conditions..
        Attestation memory a = SPI_INSTANCE.getAttestation(uint64(attestationId));
        // is the same expected criteria as the registered in attestation?
        // is the attestation expired?
        // who emmited the attestation?
        if (a.validUntil > 0 && block.timestamp > a.validUntil) return false;
        if (a.attester != address(this)) return false;

        // check if the recipient is listed
        uint256 len = a.recipients.length;
        for (uint256 i = 0; i < len; i = i.uncheckedInc()) {
            address registered = abi.decode(a.recipients[i], (address));
            if (registered == recipient) return true;
        }

        return false;
    }

    /// @notice Converts an array of addresses to an array of bytes.
    /// @param addresses The array of addresses to convert.
    /// @return An array of addresses encoded as bytes.
    function _convertAddressesToBytes(address[] calldata addresses) private pure returns (bytes[] memory) {
        uint256 len = addresses.length;
        bytes[] memory bytesArray = new bytes[](len);

        for (uint256 i = 0; i < len; i = i.uncheckedInc()) {
            bytesArray[i] = abi.encode(addresses[i]);
        }

        return bytesArray;
    }
}
