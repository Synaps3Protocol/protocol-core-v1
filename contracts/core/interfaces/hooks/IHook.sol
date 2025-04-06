// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

interface IHook {
    // check if the hook its associated with the target
    // eg. SubscriptionPolicy its allowed to process this hook 
    function validate(address caller, address target) external;
    /// @notice Called by the protocol to signal the use of the hook
    /// @param caller The address invoking the hook (e.g., the user or distributor)
    /// @param context Optional: bytes data for hook-specific usage
    function execute(address caller, bytes calldata context) external;
}
