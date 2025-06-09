// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { LedgerUpgradeable } from "contracts/core/primitives/upgradeable/LedgerUpgradeable.sol";

contract LedgerTest is Test, LedgerUpgradeable {
    function test_SetLedgerEntry() public {
        address account = vm.addr(1); // example address
        _setLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerBalance(account, address(0)), 1e18, "Expected balance should be 1e18 after setting entry");
    }

    function test_SumLedgerEntry() public {
        address account = vm.addr(1); // example address
        _sumLedgerEntry(account, 1e18, address(0));
        _sumLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerBalance(account, address(0)), 2e18, "Expected balance should be 2e18 after summation");
    }

    function test_SubLenderEntry() public {
        address account = vm.addr(1); // example address
        _sumLedgerEntry(account, 1e18, address(0));
        _sumLedgerEntry(account, 1e18, address(0));
        _subLedgerEntry(account, 1e18, address(0));
        _subLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerBalance(account, address(0)), 0, "Expected balance should be zero after subtraction");
    }
}
