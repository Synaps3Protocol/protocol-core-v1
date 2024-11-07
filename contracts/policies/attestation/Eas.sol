// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IEAS } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { Attestation } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { MultiAttestationRequest } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { AttestationRequestData } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { IAttestationProvider } from "contracts/interfaces/IAttestationProvider.sol";
import { LoopOps } from "contracts/libraries/LoopOps.sol";

contract EAS is IAttestationProvider {
    using LoopOps for uint256;

    IEAS public immutable EAS_SERVICE;
    bytes32 public immutable SCHEMA_ID;
    mapping(address => mapping(uint256 => bytes32)) public attestations;

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
    function attest(address[] calldata recipients, uint256 expireAt, bytes calldata data) external returns (uint256) {
        uint256 recipientsLen = recipients.length;
        AttestationRequestData[] memory requests = new AttestationRequestData[](recipientsLen);

        // populate attestation request
        for (uint256 i = 0; i < recipientsLen; i = i.uncheckedInc()) {
            requests[i] = AttestationRequestData({
                recipient: recipients[i],
                expirationTime: uint64(expireAt),
                revocable: false,
                refUID: 0, // No references UI
                data: data, // Encode a single uint256 as a parameter to the schema
                value: 0 // No value/ETH
            });
        }

        // we get a flattened array from eas
        MultiAttestationRequest[] memory multi = new MultiAttestationRequest[](1);
        multi[0] = MultiAttestationRequest({ schema: SCHEMA_ID, data: requests });
        // https://github.com/ethereum-attestation-service/eas-contracts/blob/master/contracts/EAS.sol
        bytes32[] memory uids = EAS_SERVICE.multiAttest(multi);

        // calculate one global attestation
        uint256 global = uint256(keccak256(abi.encodePacked(uids)));
        // associate each uid with global and account
        _associateUidsWithGlobal(global, uids, recipients);
        // on verify get the uid from global and account
        return global;
    }

    /// @notice Verifies the validity of an attestation for a given attester and recipient.
    /// @param attester The address of the original creator of the attestation.
    /// @param recipient The address of the recipient whose attestation is being verified.
    function verify(uint256 attestationId, address attester, address recipient) external view returns (bool) {
        // check attestation conditions..
        // attestationId here is expected as global
        bytes32 uid = attestations[recipient][attestationId];
        Attestation memory a = EAS_SERVICE.getAttestation(uid);
        // is the same expected criteria as the registered in attestation?
        // is the attestation expired?
        // who emmited the attestation?
        if (a.expirationTime > 0 && block.timestamp > a.expirationTime) return false;
        if (a.attester != attester) return false;
        // check if the recipient is listed
        return recipient == a.recipient;
    }

    function _associateUidsWithGlobal(uint256 global, bytes32[] memory uids, address[] memory addresses) private {
        uint256 len = addresses.length;
        for (uint256 i = 0; i < len; i = i.uncheckedInc()) {
            /// each account hold a reference to uid bounded by global
            attestations[addresses[i]][global] = uids[i];
        }
    }
}
