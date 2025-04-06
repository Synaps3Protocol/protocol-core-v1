// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

interface IHookRegistryVerifiable {
    function lookup(bytes4 interfaceId) external returns (address);
}
