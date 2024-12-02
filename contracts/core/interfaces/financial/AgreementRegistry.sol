// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

/// @title IRightsAccessAgreement
/// @notice Interface for managing agreements related to content rights access.
/// @dev This interface handles the creation, retrieval, and execution of agreements within the RightsManager context.
interface IAccessRegistry {
    /// @notice Settles an agreement by marking it inactive and transferring funds to the counterparty.
    /// @param proof The unique identifier of the agreement.
    /// @param counterparty The address that will receive the funds upon settlement.
    function settleAgreement(uint256 proof, address counterparty) external returns (T.Agreement memory);

    /// @notice Allows the initiator to quit the agreement and receive the committed funds.
    /// @param proof The unique identifier of the agreement.
    function quitAgreement(uint256 proof) external returns (T.Agreement memory);

    /// @notice Creates and stores a new agreement.
    /// @param amount The total amount committed.
    /// @param currency The currency used for the agreement.
    /// @param broker The authorized account to manage the agreement.
    /// @param parties The parties in the agreement.
    /// @param payload Additional data for execution.
    function createAgreement(
        uint256 amount,
        address currency,
        address broker,
        address[] calldata parties,
        bytes calldata payload
    ) external returns (uint256);

    /// @notice Previews an agreement by calculating fees and returning the agreement terms without committing them.
    /// @param amount The total amount committed.
    /// @param currency The currency used for the agreement.
    /// @param broker The authorized account to manage the agreement.
    /// @param parties The parties in the agreement.
    /// @param payload Additional data for execution.
    function previewAgreement(
        uint256 amount,
        address currency,
        address broker,
        address[] calldata parties,
        bytes calldata payload
    ) external view returns (T.Agreement memory);

    /// @notice Retrieves the details of an agreement based on the provided proof.
    /// @param proof The unique identifier (hash) of the agreement.
    function getAgreement(uint256 proof) external view returns (T.Agreement memory);

}
