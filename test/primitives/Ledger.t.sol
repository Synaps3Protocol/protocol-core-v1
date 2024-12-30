// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { LedgerUpgradeable } from "contracts/core/primitives/upgradeable/LedgerUpgradeable.sol";

contract LedgerTest is Test, LedgerUpgradeable {
    function test_SetLedgerEntry() public {
        address account = vm.addr(1); // example address
        _setLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerBalance(account, address(0)), 1e18);
    }

    function test_SumLedgerEntry() public {
        address account = vm.addr(1); // example address
        _sumLedgerEntry(account, 1e18, address(0));
        _sumLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerBalance(account, address(0)), 2e18);
    }

    function test_SubLenderEntry() public {
        address account = vm.addr(1); // example address
        _sumLedgerEntry(account, 1e18, address(0));
        _sumLedgerEntry(account, 1e18, address(0));
        _subLedgerEntry(account, 1e18, address(0));
        _subLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerBalance(account, address(0)), 0);
    }
}
