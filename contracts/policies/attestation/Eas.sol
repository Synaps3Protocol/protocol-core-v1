// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IEAS } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { Attestation } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { MultiAttestationRequest } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { AttestationRequestData } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { IAttestationProvider } from "@synaps3/core/interfaces/IAttestationProvider.sol";
import { LoopOps } from "@synaps3/core/libraries/LoopOps.sol";

contract EAS is IAttestationProvider {
    using LoopOps for uint256;

    IEAS public immutable EAS_SERVICE;
    bytes32 public immutable SCHEMA_ID;

    constructor(address easAddress, bytes32 schemaId) {
        EAS_SERVICE = IEAS(easAddress);
        SCHEMA_ID = schemaId;
    }

    /// @notice Returns the name of the attestor.
    /// @return The name of the attestor as a string.
    function getName() public pure returns (string memory) {
        return "EthereumAttestationService";
    }

    /// @notice Returns the address associated with the attestor.
    /// @return The address of the attestor.
    function getAddress() public view returns (address) {
        return address(EAS_SERVICE);
    }

    /// @notice Creates a new attestation with the specified data.
    /// @param recipients The addresses of the recipients of the attestation.
    /// @param expireAt The timestamp at which the attestation will expire.
    /// @param data Additional data associated with the attestation.
    function attest(
        address[] calldata recipients,
        uint256 expireAt,
        bytes calldata data
    ) external returns (uint256[] memory) {
        uint256 recipientsLen = recipients.length;
        AttestationRequestData[] memory requests = new AttestationRequestData[](recipientsLen);

        // populate attestation request
        for (uint256 i = 0; i < recipientsLen; i = i.uncheckedInc()) {
            requests[i] = AttestationRequestData({
                recipient: recipients[i],
                expirationTime: uint64(expireAt),
                revocable: false,
                refUID: 0, // No references UI
                data: data, // 
                value: 0 // No value/ETH
            });
        }

        // we get a flattened array from eas
        MultiAttestationRequest[] memory multi = new MultiAttestationRequest[](1);
        multi[0] = MultiAttestationRequest({ schema: SCHEMA_ID, data: requests });
        // https://github.com/ethereum-attestation-service/eas-contracts/blob/master/contracts/EAS.sol
        bytes32[] memory uids = EAS_SERVICE.multiAttest(multi);
        // on verify get the uid from global and account
        return _convertBytes32ToUint256(uids);
    }

    /// @notice Verifies the validity of an attestation for a given attester and recipient.
    /// @param attestationId The id of the attestation to verify.
    /// @param recipient The address of the recipient whose attestation is being verified.
    function verify(uint256 attestationId, address recipient) external view returns (bool) {
        // check attestation conditions..
        // attestationId here is expected as global
        bytes32 uid = bytes32(attestationId);
        Attestation memory a = EAS_SERVICE.getAttestation(uid);
        // is the same expected criteria as the registered in attestation?
        // is the attestation expired?
        // who emitted the attestation?
        if (a.expirationTime > 0 && block.timestamp > a.expirationTime) return false;
        if (a.attester != address(this)) return false;
        // check if the recipient is listed
        return recipient == a.recipient;
    }

    /// @dev Converts an array of bytes32 UIDs into an array of uint256 representations.
    ///      Each bytes32 element is cast to a uint256 without altering its bitwise structure.
    /// @param uids The array of bytes32 UIDs to be converted.
    function _convertBytes32ToUint256(bytes32[] memory uids) private pure returns (uint256[] memory) {
        uint256 len = uids.length;
        uint256[] memory converted = new uint256[](len);
        // uint256[] memory converted = new uint256[](len);
        for (uint256 i = 0; i < len; i = i.uncheckedInc()) {
            /// each account hold a reference to uid bounded by global
            converted[i] = uint256(uids[i]);
        }

        return converted;
    }
}
