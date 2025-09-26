// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { LockOperatorUpgradeable } from "contracts/core/primitives/upgradeable/LockOperatorUpgradeable.sol";
import { ILedgerVerifiable } from "contracts/core/interfaces/base/ILedgerVerifiable.sol";
import { ILockLocker } from "contracts/core/interfaces/base/ILockLocker.sol";
import { ILockReleaser } from "contracts/core/interfaces/base/ILockReleaser.sol";
import { ILockClaimer } from "contracts/core/interfaces/base/ILockClaimer.sol";

contract LockOperatorHarness is LockOperatorUpgradeable {
    bytes32 private constant LOCK_SLOT =
        0xece3ff917f3a3127e521e0c3f2f90ff09a3c8199be32f9b40bff79e776960800;

    function initialize() external initializer {
        __LockOperator_init();
    }

    function boostLedger(address account, uint256 amount, address currency) external {
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

    function lockedBalance(address account, address currency) external view returns (uint256 balance_) {
        bytes32 first;
        bytes32 second;
        assembly {
            mstore(0x00, account)
            mstore(0x20, LOCK_SLOT)
            first := keccak256(0x00, 0x40)

            mstore(0x00, currency)
            mstore(0x20, first)
            second := keccak256(0x00, 0x40)

            balance_ := sload(second)
        }
    }
}

contract LockOperatorUpgradeableTest is Test {
    LockOperatorHarness harness;
    address internal constant TOKEN = address(0xC0FFEE);
    address operator;
    address alice;
    address bob;
    address claimer;

    function setUp() public {
        harness = new LockOperatorHarness();
        harness.initialize();
        operator = vm.addr(1);
        alice = vm.addr(2);
        bob = vm.addr(3);
        claimer = vm.addr(4);
    }

    function test_Lock_ReducesLedgerAndTracksLocked() public {
        uint256 amount = 50 ether;
        harness.boostLedger(alice, 100 ether, TOKEN);

        vm.prank(operator);
        vm.expectEmit(true, true, false, true, address(harness));
        emit ILockLocker.FundsLocked(operator, alice, amount, TOKEN);
        harness.lock(alice, amount, TOKEN);

        assertEq(
            ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN),
            50 ether,
            "Ledger should reflect locked deduction"
        );
        assertEq(harness.lockedBalance(alice, TOKEN), amount, "Locked balance mismatch");
    }

    function test_Lock_RevertWhen_InvalidParams() public {
        harness.boostLedger(alice, 10 ether, TOKEN);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));

        vm.prank(operator);
        vm.expectRevert(err);
        harness.lock(address(0), 1 ether, TOKEN);

        vm.prank(operator);
        vm.expectRevert(err);
        harness.lock(alice, 0, TOKEN);
    }

    function test_Lock_RevertWhen_InsufficientLedgerBalance() public {
        vm.prank(operator);
        vm.expectRevert(ILockLocker.NoFundsToLock.selector);
        harness.lock(alice, 1 ether, TOKEN);
    }

    function test_Release_RestoresLedger() public {
        harness.boostLedger(alice, 80 ether, TOKEN);

        vm.prank(operator);
        harness.lock(alice, 60 ether, TOKEN);

        vm.prank(operator);
        vm.expectEmit(true, true, false, true, address(harness));
        emit ILockReleaser.FundsReleased(operator, alice, 20 ether, TOKEN);
        harness.release(alice, 20 ether, TOKEN);

        assertEq(harness.lockedBalance(alice, TOKEN), 40 ether, "Locked balance after release");
        assertEq(
            ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN),
            40 ether,
            "Ledger should regain released amount"
        );
    }

    function test_Release_RevertWhen_InsufficientLocked() public {
        harness.boostLedger(alice, 40 ether, TOKEN);
        vm.prank(operator);
        harness.lock(alice, 30 ether, TOKEN);

        vm.prank(operator);
        vm.expectRevert(ILockReleaser.NoFundsToRelease.selector);
        harness.release(alice, 40 ether, TOKEN);
    }

    function test_Claim_MovesLockedToClaimerLedger() public {
        harness.boostLedger(alice, 90 ether, TOKEN);
        vm.prank(operator);
        harness.lock(alice, 60 ether, TOKEN);

        vm.prank(claimer);
        vm.expectEmit(true, true, false, true, address(harness));
        emit ILockClaimer.FundsClaimed(claimer, alice, 25 ether, TOKEN);
        harness.claim(alice, 25 ether, TOKEN);

        assertEq(harness.lockedBalance(alice, TOKEN), 35 ether, "Locked balance after claim");
        assertEq(
            ILedgerVerifiable(address(harness)).getLedgerBalance(claimer, TOKEN),
            25 ether,
            "Claimer ledger should increase"
        );
    }

    function test_Claim_RevertWhen_InsufficientLocked() public {
        vm.prank(claimer);
        vm.expectRevert(ILockClaimer.NoFundsToClaim.selector);
        harness.claim(alice, 1 ether, TOKEN);
    }

    function test_Integration_MultiAccountFlow() public {
        harness.boostLedger(alice, 100 ether, TOKEN);
        harness.boostLedger(bob, 90 ether, TOKEN);

        vm.prank(operator);
        harness.lock(alice, 60 ether, TOKEN);

        vm.prank(operator);
        harness.lock(bob, 45 ether, TOKEN);

        vm.prank(operator);
        harness.release(alice, 20 ether, TOKEN);

        vm.prank(claimer);
        harness.claim(alice, 10 ether, TOKEN);

        vm.prank(claimer);
        harness.claim(bob, 15 ether, TOKEN);

        assertEq(harness.lockedBalance(alice, TOKEN), 30 ether, "Alice locked mismatch");
        assertEq(harness.lockedBalance(bob, TOKEN), 30 ether, "Bob locked mismatch");
        assertEq(
            ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN),
            60 ether,
            "Alice ledger mismatch"
        );
        assertEq(
            ILedgerVerifiable(address(harness)).getLedgerBalance(bob, TOKEN),
            45 ether,
            "Bob ledger mismatch"
        );
        assertEq(
            ILedgerVerifiable(address(harness)).getLedgerBalance(claimer, TOKEN),
            25 ether,
            "Claimer ledger aggregate mismatch"
        );
    }

    function testFuzz_LockReleaseCycle(uint256 seedAmount, uint256 lockAmount, uint256 releaseAmount) public {
        seedAmount = bound(seedAmount, 1 ether, 1e24);
        lockAmount = bound(lockAmount, 1 ether, seedAmount);
        releaseAmount = bound(releaseAmount, 0, lockAmount);

        harness.boostLedger(alice, seedAmount, TOKEN);

        vm.prank(operator);
        harness.lock(alice, lockAmount, TOKEN);

        if (releaseAmount > 0) {
            vm.prank(operator);
            harness.release(alice, releaseAmount, TOKEN);
        }

        uint256 expectedLocked = lockAmount - releaseAmount;
        uint256 expectedLedger = seedAmount - lockAmount + releaseAmount;

        assertEq(harness.lockedBalance(alice, TOKEN), expectedLocked, "Fuzz locked mismatch");
        assertEq(
            ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN),
            expectedLedger,
            "Fuzz ledger mismatch"
        );
        assertEq(expectedLocked + expectedLedger, seedAmount, "Conservation after release");
    }

    function testFuzz_ClaimMaintainsConservation(uint256 seedAmount, uint256 lockAmount, uint256 claimAmount) public {
        seedAmount = bound(seedAmount, 1 ether, 1e24);
        lockAmount = bound(lockAmount, 1 ether, seedAmount);
        claimAmount = bound(claimAmount, 1 ether, lockAmount);

        harness.boostLedger(alice, seedAmount, TOKEN);
        vm.prank(operator);
        harness.lock(alice, lockAmount, TOKEN);

        vm.prank(claimer);
        harness.claim(alice, claimAmount, TOKEN);

        uint256 lockedLeft = lockAmount - claimAmount;
        uint256 ledgerAlice = ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN);
        uint256 ledgerClaimer = ILedgerVerifiable(address(harness)).getLedgerBalance(claimer, TOKEN);

        assertEq(harness.lockedBalance(alice, TOKEN), lockedLeft, "Locked left mismatch");
        assertEq(ledgerAlice + lockedLeft + ledgerClaimer, seedAmount, "Seed conservation broken");
    }
}

contract LockOperatorHandler is Test {
    LockOperatorHarness public immutable harness;
    address[] internal accounts;
    address internal constant TOKEN = address(0xC0FFEE);

    mapping(address => uint256) internal ledgerExpectation;
    mapping(address => uint256) internal lockedExpectation;

    constructor(LockOperatorHarness operator) {
        harness = operator;
        for (uint256 i = 0; i < 3; i++) {
            accounts.push(vm.addr(i + 10));
        }
    }

    function seedLedger(uint256 index, uint256 amount) external {
        vm.assume(index < accounts.length);
        amount = bound(amount, 1, 1e27);
        address account = accounts[index];
        harness.boostLedger(account, amount, TOKEN);
        ledgerExpectation[account] += amount;
    }

    function lock(uint256 index, uint256 amount) external {
        vm.assume(index < accounts.length);
        address account = accounts[index];
        uint256 available = ledgerExpectation[account];
        vm.assume(amount > 0 && amount <= available);

        vm.prank(account);
        harness.lock(account, amount, TOKEN);

        ledgerExpectation[account] = available - amount;
        lockedExpectation[account] += amount;
    }

    function release(uint256 index, uint256 amount) external {
        vm.assume(index < accounts.length);
        address account = accounts[index];
        uint256 locked = lockedExpectation[account];
        vm.assume(amount > 0 && amount <= locked);

        vm.prank(account);
        harness.release(account, amount, TOKEN);

        lockedExpectation[account] = locked - amount;
        ledgerExpectation[account] += amount;
    }

    function claim(uint256 lockedIdx, uint256 claimerIdx, uint256 amount) external {
        vm.assume(lockedIdx < accounts.length && claimerIdx < accounts.length && lockedIdx != claimerIdx);
        address account = accounts[lockedIdx];
        address claimerAccount = accounts[claimerIdx];
        uint256 locked = lockedExpectation[account];
        vm.assume(amount > 0 && amount <= locked);

        vm.prank(claimerAccount);
        harness.claim(account, amount, TOKEN);

        lockedExpectation[account] = locked - amount;
        ledgerExpectation[claimerAccount] += amount;
    }

    function accountsLength() external view returns (uint256) {
        return accounts.length;
    }

    function accountAt(uint256 idx) external view returns (address) {
        return accounts[idx];
    }

    function expectedLedger(address account) external view returns (uint256) {
        return ledgerExpectation[account];
    }

    function expectedLocked(address account) external view returns (uint256) {
        return lockedExpectation[account];
    }

    function token() external pure returns (address) {
        return TOKEN;
    }
}

contract LockOperatorUpgradeableInvariantTest is Test {
    LockOperatorHarness harness;
    LockOperatorHandler handler;

    function setUp() public {
        harness = new LockOperatorHarness();
        harness.initialize();
        handler = new LockOperatorHandler(harness);
        targetContract(address(handler));
    }

    function invariant_LedgerBalancesMatchExpectation() external {
        uint256 len = handler.accountsLength();
        for (uint256 i = 0; i < len; i++) {
            address account = handler.accountAt(i);
            assertEq(
                ILedgerVerifiable(address(harness)).getLedgerBalance(account, handler.token()),
                handler.expectedLedger(account),
                "Ledger expectation mismatch"
            );
        }
    }

    function invariant_LockedBalancesMatchExpectation() external {
        uint256 len = handler.accountsLength();
        for (uint256 i = 0; i < len; i++) {
            address account = handler.accountAt(i);
            assertEq(
                harness.lockedBalance(account, handler.token()),
                handler.expectedLocked(account),
                "Locked expectation mismatch"
            );
        }
    }

    function invariant_TotalConservationHolds() external {
        uint256 len = handler.accountsLength();
        uint256 expectedLedgerSum;
        uint256 expectedLockedSum;
        uint256 actualLedgerSum;
        uint256 actualLockedSum;
        address tokenAddress = handler.token();

        for (uint256 i = 0; i < len; i++) {
            address account = handler.accountAt(i);
            expectedLedgerSum += handler.expectedLedger(account);
            expectedLockedSum += handler.expectedLocked(account);
            actualLedgerSum += ILedgerVerifiable(address(harness)).getLedgerBalance(account, tokenAddress);
            actualLockedSum += harness.lockedBalance(account, tokenAddress);
        }

        assertEq(actualLedgerSum, expectedLedgerSum, "Aggregated ledger mismatch");
        assertEq(actualLockedSum, expectedLockedSum, "Aggregated locked mismatch");
        assertEq(actualLedgerSum + actualLockedSum, expectedLedgerSum + expectedLockedSum, "Total conservation mismatch");
    }
}
