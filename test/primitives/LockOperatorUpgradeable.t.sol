// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { LockOperatorUpgradeable } from "contracts/core/primitives/upgradeable/LockOperatorUpgradeable.sol";
import { ILedgerVerifiable } from "contracts/core/interfaces/base/ILedgerVerifiable.sol";
import { ILockLocker } from "contracts/core/interfaces/base/ILockLocker.sol";
import { ILockReleaser } from "contracts/core/interfaces/base/ILockReleaser.sol";
import { ILockClaimer } from "contracts/core/interfaces/base/ILockClaimer.sol";

contract LockOperatorHarness is LockOperatorUpgradeable {
    function initialize() external initializer {
        __LockOperator_init();
    }

    function seedLedger(address account, uint256 amount, address currency) external {
        _sumLedgerEntry(account, amount, currency);
    }

    function lock(address account, uint256 amount, address currency) external override returns (uint256) {
        return _lock(account, amount, currency);
    }

    function release(address account, uint256 amount, address currency) external override returns (uint256) {
        return _release(account, amount, currency);
    }

    function claim(address account, uint256 amount, address currency) external override returns (uint256) {
        return _claim(account, amount, currency);
    }
}

contract LockOperatorUpgradeableTest is Test {
    LockOperatorHarness internal harness;
    address internal constant TOKEN = address(0xC0FFEE);
    address internal alice = vm.addr(1);
    address internal bob = vm.addr(2);
    address internal claimer = vm.addr(3);

    function setUp() public {
        harness = new LockOperatorHarness();
        harness.initialize();
    }

    function test_LockDeductsLedgerAndTracksLocked() public {
        harness.seedLedger(alice, 120 ether, TOKEN);

        vm.expectEmit(true, true, false, true, address(harness));
        emit ILockLocker.FundsLocked(address(this), alice, 40 ether, TOKEN);
        harness.lock(alice, 40 ether, TOKEN);

        assertEq(ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN), 80 ether, "Ledger deduction mismatch");
        assertEq(harness.getLockedBalance(alice, TOKEN), 40 ether, "Locked balance mismatch");
    }

    function test_Lock_RevertWhen_NoFunds() public {
        vm.expectRevert(ILockLocker.NoFundsToLock.selector);
        harness.lock(alice, 1 ether, TOKEN);
    }

    function test_Lock_RevertWhen_InvalidParams() public {
        harness.seedLedger(alice, 10 ether, TOKEN);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));

        vm.expectRevert(err);
        harness.lock(address(0), 1 ether, TOKEN);

        vm.expectRevert(err);
        harness.lock(alice, 0, TOKEN);
    }

    function test_Release_RestoresLedger() public {
        harness.seedLedger(alice, 90 ether, TOKEN);
        harness.lock(alice, 60 ether, TOKEN);

        vm.expectEmit(true, true, false, true, address(harness));
        emit ILockReleaser.FundsReleased(address(this), alice, 25 ether, TOKEN);
        harness.release(alice, 25 ether, TOKEN);

        assertEq(harness.getLockedBalance(alice, TOKEN), 35 ether, "Locked after release mismatch");
        assertEq(ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN), 55 ether, "Ledger after release mismatch");
    }

    function test_Release_RevertWhen_InsufficientLocked() public {
        harness.seedLedger(alice, 20 ether, TOKEN);
        harness.lock(alice, 10 ether, TOKEN);
        vm.expectRevert(ILockReleaser.NoFundsToRelease.selector);
        harness.release(alice, 15 ether, TOKEN);
    }

    function test_Claim_MovesLockedToClaimerLedger() public {
        harness.seedLedger(alice, 70 ether, TOKEN);
        harness.lock(alice, 30 ether, TOKEN);

        vm.expectEmit(true, true, false, true, address(harness));
        emit ILockClaimer.FundsClaimed(claimer, alice, 18 ether, TOKEN);
        vm.prank(claimer);
        harness.claim(alice, 18 ether, TOKEN);

        ILedgerVerifiable ledger = ILedgerVerifiable(address(harness));
        assertEq(harness.getLockedBalance(alice, TOKEN), 12 ether, "Locked remainder mismatch");
        assertEq(ledger.getLedgerBalance(claimer, TOKEN), 18 ether, "Claimer ledger mismatch");
        assertEq(ledger.getLedgerBalance(alice, TOKEN), 40 ether, "Alice ledger should reflect lock deduction");
    }

    function test_Claim_RevertWhen_InsufficientLocked() public {
        harness.seedLedger(alice, 30 ether, TOKEN);
        harness.lock(alice, 10 ether, TOKEN);

        vm.expectRevert(ILockClaimer.NoFundsToClaim.selector);
        harness.claim(alice, 12 ether, TOKEN);
    }

    function test_Integration_LockReleaseClaimFlow() public {
        harness.seedLedger(alice, 200 ether, TOKEN);
        harness.lock(alice, 120 ether, TOKEN);
        harness.release(alice, 30 ether, TOKEN);
        vm.prank(claimer);
        harness.claim(alice, 50 ether, TOKEN);

        uint256 locked = harness.getLockedBalance(alice, TOKEN);
        ILedgerVerifiable ledger = ILedgerVerifiable(address(harness));
        uint256 aliceLedger = ledger.getLedgerBalance(alice, TOKEN);
        uint256 claimerLedger = ledger.getLedgerBalance(claimer, TOKEN);

        assertEq(locked, 40 ether, "Final locked mismatch");
        assertEq(aliceLedger, 110 ether, "Alice ledger mismatch");
        assertEq(claimerLedger, 50 ether, "Claimer ledger mismatch");
        assertEq(locked + aliceLedger + claimerLedger, 200 ether, "Total conservation mismatch");
    }
}
