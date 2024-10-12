// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "contracts/libraries/Types.sol";

/// @title IRightsAccessAgreement
/// @notice Interface for managing agreements related to content rights access.
/// @dev This interface handles the creation, retrieval, and execution of agreements within the RightsManager context.
interface IRightsAccessAgreement {
    /// @notice Settles the agreement associated with the given proof, preparing it for payment processing.
    /// @dev This function retrieves the agreement and marks it as settled to trigger any associated payments.
    /// @param proof The unique identifier of the agreement to settle.
    /// @return The agreement object associated with the provided proof.
    function settleAgreement(bytes32 proof) external returns (T.Agreement memory);

    /// @notice Creates a new agreement between the account and the content holder, returning a unique agreement identifier.
    /// @param total The total amount involved in the agreement.
    /// @param currency The address of the ERC20 token (or native currency) being used in the agreement.
    /// @param holder The address of the content holder whose content is being accessed.
    /// @param account The address of the account proposing the agreement.
    /// @param data Additional data required to execute the policy.
    /// @return A unique identifier (agreementProof) representing the created agreement.
    function createAgreement(
        uint256 total,
        address currency,
        address holder,
        address account,
        bytes calldata data
    ) external returns (bytes32);

    /// @notice Checks if a given proof corresponds to an active agreement.
    /// @dev Verifies the existence and active status of the agreement in storage.
    /// @param proof The unique identifier of the agreement to validate.
    /// @return True if the agreement is active, false otherwise.
    function isValidProof(bytes32 proof) external view returns (bool);
}
