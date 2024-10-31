// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IFeesCollector {
    /// @notice Emitted when fees are disbursed to the treasury.
    /// @param target The address receiving the disbursed fees.
    /// @param amount The amount of fees being disbursed.
    /// @param currency The currency used for the disbursement.
    event FeesDisbursed(address indexed target, uint256 amount, address currency);

    /// @notice Disburses funds from the contract to the treasury.
    /// @param currency The address of the ERC20 token to disburse tokens.
    function disburse(address currency) external returns (uint256);
}
