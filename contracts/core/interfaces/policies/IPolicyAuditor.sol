// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IPolicyAuditorRegistrable } from "@synaps3/core/interfaces/policies/IPolicyAuditorRegistrable.sol";
import { IPolicyAuditorVerifiable } from "@synaps3/core/interfaces/policies/IPolicyAuditorVerifiable.sol";

/// @title IPolicyAuditor
/// @notice Interface for managing the registration and verification of policies auditors within the system.
interface IPolicyAuditor is IPolicyAuditorRegistrable, IPolicyAuditorVerifiable {}
