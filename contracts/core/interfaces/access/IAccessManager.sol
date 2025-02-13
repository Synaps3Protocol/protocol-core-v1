// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

// Centralized import for IAccessManager interface from OpenZeppelin.
// This import acts as a single source for all dependencies on IAccessManager within the protocol,
// allowing easier management of library updates and ensuring uniformity across the protocol.
// Any future changes or updates to the OpenZeppelin dependency can be managed here,
// so other contracts that rely on IAccessManager do not need to import it directly from OpenZeppelin.
// solhint-disable-next-line no-unused-import
import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
