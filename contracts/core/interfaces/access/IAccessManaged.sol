// SPDX-License-Identifier: BUSL-1.1
// Following NatSpec format convention: https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

// Centralized import for IAccessManaged interface from OpenZeppelin.
// This serves as a single import point for the IAccessManaged dependency within the protocol,
// ensuring consistent usage and simplifying future updates. By importing IAccessManaged here,
// other contracts in the protocol can reference this file instead of importing directly from OpenZeppelin,
// which simplifies dependency management and promotes uniformity throughout the project.
// solhint-disable-next-line no-unused-import
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
