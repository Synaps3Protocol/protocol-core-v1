// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPolicyAuditorRegistrable } from "contracts/interfaces/policies/IPolicyAuditorRegistrable.sol";
import { IPolicyAuditorVerifiable } from "contracts/interfaces/policies/IPolicyAuditorVerifiable.sol";

/// @title IPolicyAuditor
/// @notice Interface for managing the registration and verification of policy auditors within the system.
/// @dev This interface combines functionalities related to registering and verifying policy auditors, ensuring compliance with governance processes.
interface IPolicyAuditor is IPolicyAuditorRegistrable, IPolicyAuditorVerifiable {}
