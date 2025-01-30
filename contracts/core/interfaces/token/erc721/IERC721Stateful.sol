// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC721StatefulVerifiable } from "@synaps3/core/interfaces/token/erc721/IERC721StatefulVerifiable.sol";
import { IERC721StatefulSwitchable } from "@synaps3/core/interfaces/token/erc721/IERC721StatefulSwitchable.sol";

/// @title IERC721Stateful
/// @notice Unified interface for stateful ERC721 tokens, combining verification and activation state management.
/// @dev This interface extends both `IERC721StatefulVerifiable` and `IERC721StatefulSwitchable`
///      to enable token state verification and state switching functionalities.
interface IERC721Stateful is IERC721StatefulVerifiable, IERC721StatefulSwitchable {}
