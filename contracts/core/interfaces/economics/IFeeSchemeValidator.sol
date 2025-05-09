// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { T } from "@synaps3/core/primitives/Types.sol";

/// @title IFeeSchemeValidator
/// @notice Interface for authorizing which fee schemes are accepted in a protocol context.
/// @dev This contract represents a context-bound authorizer, so no target is passed.
interface IFeeSchemeValidator {
    /// @notice Returns true if the fee scheme is supported by this contract.
    /// @param scheme The scheme to check.
    /// @return True if supported, false if explicitly not supported.
    function isFeeSchemeSupported(T.Scheme scheme) external view returns (bool);
}
