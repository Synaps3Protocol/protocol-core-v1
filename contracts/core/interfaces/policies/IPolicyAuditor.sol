// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPolicyAuditorRegistrable } from "contracts/core/interfaces/policies/IPolicyAuditorRegistrable.sol";
import { IPolicyAuditorVerifiable } from "contracts/core/interfaces/policies/IPolicyAuditorVerifiable.sol";

/// @title IPolicyAuditor
/// @notice Interface for managing the registration and verification of policies auditors within the system.
interface IPolicyAuditor is IPolicyAuditorRegistrable, IPolicyAuditorVerifiable {}