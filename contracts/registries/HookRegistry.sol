// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

// IAccessHook with preset rules of access for holders account or assets
// eg: holder can set if under some conditions the user can access
// - time locked free access => access to my content for the first 7 days if not already accessed
// - gated access conditions => hold X NFT and access my asset id 123
// - locked access to N user

// ISplitHook with earning splits
