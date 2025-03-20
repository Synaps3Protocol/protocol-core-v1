// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { ICustodianExpirable } from "@synaps3/core/interfaces/custody/ICustodianExpirable.sol";
import { ICustodianRegistrable } from "@synaps3/core/interfaces/custody/ICustodianRegistrable.sol";
import { ICustodianVerifiable } from "@synaps3/core/interfaces/custody/ICustodianVerifiable.sol";

/// @title ICustodianReferendum
/// @notice Interface that defines the necessary operations for managing custodian registration.
interface ICustodianReferendum is ICustodianRegistrable, ICustodianVerifiable, ICustodianExpirable {}
