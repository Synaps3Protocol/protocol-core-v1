// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

/// @title IAgreementSettler
/// @notice Interface for settling financial agreements.
/// @dev This interface handles the execution, quitting, and retrieval of settled agreements.
interface IAgreementSettler {
    /// @notice Settles an agreement by marking it inactive and transferring funds to the counterparty.
    /// @param proof The unique identifier of the agreement.
    /// @param counterparty The address that will receive the funds upon settlement.
    function settleAgreement(uint256 proof, address counterparty) external returns (T.Agreement memory);

    /// @notice Allows the initiator to quit the agreement and receive the committed funds.
    /// @param proof The unique identifier of the agreement.
    function quitAgreement(uint256 proof) external returns (T.Agreement memory);

}
