// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { LedgerUpgradeable } from "contracts/core/primitives/upgradeable/LedgerUpgradeable.sol";

contract LedgerUpgradeableHarness is LedgerUpgradeable {
    function initialize() external initializer {
        __Ledger_init();
    }

    function setEntry(address account, uint256 amount, address currency) external {
        _setLedgerEntry(account, amount, currency);
    }

    function sumEntry(address account, uint256 amount, address currency) external {
        _sumLedgerEntry(account, amount, currency);
    }

    function subEntry(address account, uint256 amount, address currency) external {
        _subLedgerEntry(account, amount, currency);
    }
}

contract LedgerUpgradeableTest is Test {
    LedgerUpgradeableHarness internal harness;
    address internal alice = vm.addr(11);
    address internal bob = vm.addr(12);
    address internal currency = vm.addr(33);

    function setUp() public {
        harness = new LedgerUpgradeableHarness();
        harness.initialize();
    }

    function test_SetEntry_SetsBalance() public {
        harness.setEntry(alice, 50 ether, currency);
        assertEq(harness.getLedgerBalance(alice, currency), 50 ether, "Set should override balance");
    }

    function test_SumEntry_IncrementsBalance() public {
        harness.setEntry(alice, 10 ether, currency);
        harness.sumEntry(alice, 5 ether, currency);
        assertEq(harness.getLedgerBalance(alice, currency), 15 ether, "Sum should add amount");
    }

    function test_SubEntry_DecrementsBalance() public {
        harness.setEntry(alice, 20 ether, currency);
        harness.subEntry(alice, 7 ether, currency);
        assertEq(harness.getLedgerBalance(alice, currency), 13 ether, "Sub should remove amount");
    }

    function test_SubEntry_AllowsReducingToZero() public {
        harness.setEntry(alice, 8 ether, currency);
        harness.subEntry(alice, 8 ether, currency);
        assertEq(harness.getLedgerBalance(alice, currency), 0, "Balance should reach zero");
    }

    function test_SetEntry_IsolatedPerAccountAndCurrency() public {
        harness.setEntry(alice, 15 ether, currency);
        harness.setEntry(bob, 30 ether, vm.addr(44));

        assertEq(harness.getLedgerBalance(alice, currency), 15 ether, "Alice balance mismatch");
        assertEq(harness.getLedgerBalance(bob, vm.addr(44)), 30 ether, "Bob balance mismatch");
        assertEq(harness.getLedgerBalance(bob, currency), 0, "Cross account balances should stay zero");
    }

    function test_SequentialOperationsConserveMath() public {
        harness.setEntry(alice, 40 ether, currency);
        harness.sumEntry(alice, 12 ether, currency);
        harness.subEntry(alice, 5 ether, currency);
        harness.sumEntry(alice, 3 ether, currency);

        assertEq(harness.getLedgerBalance(alice, currency), 50 ether, "Sequential math mismatch");
    }
}
