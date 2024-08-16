pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "contracts/base/upgradeable/LedgerUpgradeable.sol";


contract LedgerTest is Test, LedgerUpgradeable {
    function test_SetLedgerEntry() public {
        address account = vm.addr(1); // example address
        _setLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerEntry(account, address(0)), 1e18);
    }

    function test_SumLedgerEntry() public {
        address account = vm.addr(1); // example address
        _sumLedgerEntry(account, 1e18, address(0));
        _sumLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerEntry(account, address(0)), 2e18);
    }

    function test_SubLenderEntry() public {
        address account = vm.addr(1); // example address
        _sumLedgerEntry(account, 1e18, address(0));
        _sumLedgerEntry(account, 1e18, address(0));
        _subLedgerEntry(account, 1e18, address(0));
        _subLedgerEntry(account, 1e18, address(0));
        assertEq(getLedgerEntry(account, address(0)), 0);
    }

}
