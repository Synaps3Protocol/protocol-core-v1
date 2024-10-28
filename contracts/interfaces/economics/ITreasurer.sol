// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITreasurer {
    /// @notice Emitted when fees are disbursed to the treasury.
    /// @param target The address receiving the disbursed fees.
    /// @param amount The amount of fees being disbursed.
    /// @param currency The currency used for the disbursement.
    event FeesDisbursed(address indexed target, uint256 amount, address currency);

    /// @notice Disburses funds from the contract to the treasury.
    /// @param currency The address of the ERC20 token to disburse tokens.
    /// @dev This function can only be called by governance or an authorized entity.
    function disburse(address currency) external;
}
