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
    LedgerUpgradeableHarness harness;

    function setUp() public {
        harness = new LedgerUpgradeableHarness();
        harness.initialize();
    }

    function test_SetEntry_SetsBalance() public {
        address account = address(0xBEEF);
        address currency = address(0xCAFE);
        uint256 amount = 123 ether;

        harness.setEntry(account, amount, currency);

        assertEq(harness.getLedgerBalance(account, currency), amount, "Ledger should equal set amount");
    }

    function test_SumEntry_Accumulates() public {
        address account = address(0xA11CE);
        address currency = address(0xC0FFEE);

        harness.setEntry(account, 10 ether, currency);
        harness.sumEntry(account, 5 ether, currency);

        assertEq(harness.getLedgerBalance(account, currency), 15 ether, "Sum should increase balance");
    }

    function test_SubEntry_Decrements() public {
        address account = address(0xDEAD);
        address currency = address(0xBADDAD);

        harness.setEntry(account, 20 ether, currency);
        harness.subEntry(account, 7 ether, currency);

        assertEq(harness.getLedgerBalance(account, currency), 13 ether, "Sub should decrease balance");
    }

    function testFuzz_SetAndAdjust(uint256 amount, uint256 addAmount, uint256 subAmount) public {
        amount = bound(amount, 1, type(uint96).max);
        addAmount = bound(addAmount, 0, type(uint96).max - amount);
        subAmount = bound(subAmount, 0, amount + addAmount);

        address account = vm.addr(111);
        address currency = vm.addr(222);

        harness.setEntry(account, amount, currency);
        harness.sumEntry(account, addAmount, currency);
        harness.subEntry(account, subAmount, currency);

        uint256 expected = amount + addAmount - subAmount;
        assertEq(harness.getLedgerBalance(account, currency), expected, "Ledger after adjustments mismatch");
    }
}

contract LedgerUpgradeableHandler is Test {
    LedgerUpgradeableHarness public immutable harness;

    struct Key {
        address account;
        address currency;
    }

    Key[] private _keys;
    mapping(bytes32 => bool) private _tracked;
    mapping(bytes32 => uint256) private _expected;

    constructor(LedgerUpgradeableHarness harness_) {
        harness = harness_;
    }

    function setEntry(address account, address currency, uint256 amount) external {
        if (account == address(0) || currency == address(0)) return;
        harness.setEntry(account, amount, currency);

        bytes32 key = keccak256(abi.encode(account, currency));
        if (!_tracked[key]) {
            _tracked[key] = true;
            _keys.push(Key({ account: account, currency: currency }));
        }
        _expected[key] = amount;
    }

    function sumEntry(address account, address currency, uint256 amount) external {
        if (account == address(0) || currency == address(0)) return;

        bytes32 key = keccak256(abi.encode(account, currency));
        uint256 current = _tracked[key] ? _expected[key] : harness.getLedgerBalance(account, currency);
        uint256 newBalance = current + amount;

        harness.sumEntry(account, amount, currency);

        if (!_tracked[key]) {
            _tracked[key] = true;
            _keys.push(Key({ account: account, currency: currency }));
        }
        _expected[key] = newBalance;
    }

    function subEntry(address account, address currency, uint256 amount) external {
        if (account == address(0) || currency == address(0)) return;

        bytes32 key = keccak256(abi.encode(account, currency));
        uint256 current = _tracked[key] ? _expected[key] : harness.getLedgerBalance(account, currency);
        if (amount > current) return; // avoid underflow

        harness.subEntry(account, amount, currency);

        if (!_tracked[key]) {
            _tracked[key] = true;
            _keys.push(Key({ account: account, currency: currency }));
        }
        _expected[key] = current - amount;
    }

    function keysLength() external view returns (uint256) {
        return _keys.length;
    }

    function keyAt(uint256 index) external view returns (Key memory) {
        return _keys[index];
    }

    function expectedBalance(address account, address currency) external view returns (uint256) {
        bytes32 key = keccak256(abi.encode(account, currency));
        return _expected[key];
    }
}

contract LedgerUpgradeableInvariantTest is Test {
    LedgerUpgradeableHarness harness;
    LedgerUpgradeableHandler handler;

    function setUp() public {
        harness = new LedgerUpgradeableHarness();
        harness.initialize();
        handler = new LedgerUpgradeableHandler(harness);
        targetContract(address(handler));
    }

    function invariant_LedgerMatchesExpected() external view {
        uint256 len = handler.keysLength();
        for (uint256 i = 0; i < len; i++) {
            LedgerUpgradeableHandler.Key memory key = handler.keyAt(i);
            uint256 expected = handler.expectedBalance(key.account, key.currency);
            assertEq(harness.getLedgerBalance(key.account, key.currency), expected, "Ledger mismatch");
        }
    }
}

