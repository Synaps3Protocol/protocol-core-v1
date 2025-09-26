// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { AllowanceOperatorUpgradeable } from "contracts/core/primitives/upgradeable/AllowanceOperatorUpgradeable.sol";
import { ILedgerVerifiable } from "contracts/core/interfaces/base/ILedgerVerifiable.sol";
import { IAllowanceApprovable } from "contracts/core/interfaces/base/IAllowanceApprovable.sol";
import { IAllowanceCollectable } from "contracts/core/interfaces/base/IAllowanceCollectable.sol";

contract AllowanceOperatorHarness is AllowanceOperatorUpgradeable {
    function initialize() external initializer {
        __AllowanceOperator_init();
    }

    function boostLedger(address account, uint256 amount, address currency) external {
        _sumLedgerEntry(account, amount, currency);
    }

    // IAllowanceOperator interface
    function approve(address to, uint256 amount, address currency) external override returns (uint256) {
        return _approve(to, amount, currency);
    }

    function revoke(address to, uint256 amount, address currency) external override returns (uint256) {
        return _revoke(to, amount, currency);
    }

    function collect(address from, uint256 amount, address currency) external override returns (uint256) {
        return _collect(from, amount, currency);
    }


}

contract AllowanceOperatorTest is Test {
    AllowanceOperatorHarness harness;
    address internal constant TOKEN = address(0xC0FFEE);
    address alice;
    address bob;
    address carol;

    function setUp() public {
        harness = new AllowanceOperatorHarness();
        harness.initialize();
        alice = vm.addr(1);
        bob = vm.addr(2);
        carol = vm.addr(3);
    }

    function test_Approve_SetsAllowanceAndEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(harness));
        emit IAllowanceApprovable.FundsApproved(alice, bob, 10, TOKEN);
        harness.approve(bob, 10, TOKEN);

        assertEq(harness.getApprovedAmount(alice, bob, TOKEN), 10, "Allowance mismatch");
    }

    function test_Approve_RevertWhen_InvalidParams() public {
        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        harness.approve(address(0), 10, TOKEN);

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        harness.approve(bob, 0, TOKEN);
    }

    function test_Approve_RevertWhen_SelfApproval() public {
        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        harness.approve(alice, 1, TOKEN);
    }

    function test_Revoke_RemovesAllowance() public {
        vm.startPrank(alice);
        harness.approve(bob, 20, TOKEN);
        harness.revoke(bob, 5, TOKEN);
        vm.stopPrank();

        assertEq(harness.getApprovedAmount(alice, bob, TOKEN), 15, "Allowance after revoke mismatch");
    }

    function test_Revoke_RevertWhen_ExceedsAllowance() public {
        vm.startPrank(alice);
        harness.approve(bob, 5, TOKEN);
        vm.expectRevert(bytes4(keccak256("NoFundsToRevoke()")));
        harness.revoke(bob, 6, TOKEN);
        vm.stopPrank();
    }

    function test_Collect_TransfersApprovedFunds() public {
        vm.prank(alice);
        harness.approve(bob, 40, TOKEN);
        harness.boostLedger(alice, 40, TOKEN);

        vm.prank(bob);
        vm.expectEmit(true, true, false, true, address(harness));
        emit IAllowanceCollectable.FundsCollected(alice, bob, 35, TOKEN);
        harness.collect(alice, 35, TOKEN);

        assertEq(harness.getApprovedAmount(alice, bob, TOKEN), 5, "Remaining allowance mismatch");
        assertEq(ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN), 5, "Alice ledger mismatch");
        assertEq(ILedgerVerifiable(address(harness)).getLedgerBalance(bob, TOKEN), 35, "Bob ledger mismatch");
    }

    function test_Collect_RevertWhen_NoApproval() public {
        harness.boostLedger(alice, 20, TOKEN);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NoFundsToCollect()")));
        harness.collect(alice, 10, TOKEN);
    }

    function test_Collect_RevertWhen_InsufficientBalance() public {
        vm.prank(alice);
        harness.approve(bob, 10, TOKEN);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NoFundsToCollect()")));
        harness.collect(alice, 5, TOKEN);
    }

    function test_Integration_MultiRecipientFlow() public {
        vm.prank(alice);
        harness.approve(bob, 30, TOKEN);
        vm.prank(alice);
        harness.approve(carol, 15, TOKEN);
        harness.boostLedger(alice, 45, TOKEN);

        vm.prank(bob);
        harness.collect(alice, 20, TOKEN);

        vm.prank(carol);
        harness.collect(alice, 10, TOKEN);

        assertEq(harness.getApprovedAmount(alice, bob, TOKEN), 10, "Bob remaining allowance");
        assertEq(harness.getApprovedAmount(alice, carol, TOKEN), 5, "Carol remaining allowance");
        assertEq(ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN), 15, "Alice ledger balance");
        assertEq(ILedgerVerifiable(address(harness)).getLedgerBalance(bob, TOKEN), 20, "Bob ledger balance");
        assertEq(ILedgerVerifiable(address(harness)).getLedgerBalance(carol, TOKEN), 10, "Carol ledger balance");
    }

    function testFuzz_ApproveRevokeCycle(uint256 amount, uint256 revokeAmount) public {
        amount = bound(amount, 1, 1e24);
        revokeAmount = bound(revokeAmount, 1, amount);

        vm.prank(alice);
        harness.approve(bob, amount, TOKEN);

        vm.prank(alice);
        harness.revoke(bob, revokeAmount, TOKEN);

        assertEq(harness.getApprovedAmount(alice, bob, TOKEN), amount - revokeAmount, "Allowance after fuzz revoke mismatch");
    }

    function testFuzz_CollectMaintainsLedger(uint256 deposit, uint256 collectAmount) public {
        deposit = bound(deposit, 1e18, 1e24);
        collectAmount = bound(collectAmount, 1e18, deposit);

        vm.prank(alice);
        harness.approve(bob, deposit, TOKEN);
        harness.boostLedger(alice, deposit, TOKEN);

        vm.prank(bob);
        harness.collect(alice, collectAmount, TOKEN);

        uint256 total =
            ILedgerVerifiable(address(harness)).getLedgerBalance(alice, TOKEN) +
            ILedgerVerifiable(address(harness)).getLedgerBalance(bob, TOKEN);
        assertEq(total, deposit, "Ledger conservation failed");
    }
}

contract AllowanceHandler is Test {
    AllowanceOperatorHarness public immutable harness;
    address[] internal accounts;
    address internal constant TOKEN = address(0xC0FFEE);
    uint256 internal constant MAX_TEST_AMOUNT = 1e24;

    mapping(address => uint256) internal ledgerExpectation;
    mapping(bytes32 => uint256) internal allowanceExpectation;

    constructor(AllowanceOperatorHarness operator) {
        harness = operator;
        for (uint256 i = 0; i < 3; i++) {
            accounts.push(vm.addr(i + 10));
        }
    }

    function seedLedger(uint256 index, uint256 amount) external {
        vm.assume(index < accounts.length);
        address account = accounts[index];
        amount = bound(amount, 1, MAX_TEST_AMOUNT);
        harness.boostLedger(account, amount, TOKEN);
        ledgerExpectation[account] += amount;
    }

    function approve(uint256 fromIdx, uint256 toIdx, uint256 amount) external {
        vm.assume(fromIdx < accounts.length && toIdx < accounts.length && fromIdx != toIdx);
        address from = accounts[fromIdx];
        address to = accounts[toIdx];
        amount = bound(amount, 1, MAX_TEST_AMOUNT);

        vm.prank(from);
        harness.approve(to, amount, TOKEN);

        bytes32 key = keccak256(abi.encode(from, to));
        allowanceExpectation[key] += amount;
    }

    function revoke(uint256 fromIdx, uint256 toIdx, uint256 amount) external {
        vm.assume(fromIdx < accounts.length && toIdx < accounts.length && fromIdx != toIdx);
        address from = accounts[fromIdx];
        address to = accounts[toIdx];
        bytes32 key = keccak256(abi.encode(from, to));
        uint256 expected = allowanceExpectation[key];
        if (expected == 0) return;
        amount = bound(amount, 1, expected);

        vm.prank(from);
        harness.revoke(to, amount, TOKEN);
        allowanceExpectation[key] = expected - amount;
    }

    function collect(uint256 fromIdx, uint256 toIdx, uint256 amount) external {
        vm.assume(fromIdx < accounts.length && toIdx < accounts.length && fromIdx != toIdx);
        address from = accounts[fromIdx];
        address to = accounts[toIdx];
        bytes32 key = keccak256(abi.encode(from, to));
        uint256 allowance = allowanceExpectation[key];
        uint256 availableLedger = ledgerExpectation[from];
        if (allowance == 0 || availableLedger == 0) return;
        uint256 maxCollect = allowance < availableLedger ? allowance : availableLedger;
        amount = bound(amount, 1, maxCollect);

        vm.prank(to);
        harness.collect(from, amount, TOKEN);

        allowanceExpectation[key] = allowance - amount;
        ledgerExpectation[from] -= amount;
        ledgerExpectation[to] += amount;
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

    function expectedAllowance(address from, address to) external view returns (uint256) {
        return allowanceExpectation[keccak256(abi.encode(from, to))];
    }

    function token() external pure returns (address) {
        return TOKEN;
    }
}

contract AllowanceOperatorInvariantTest is Test {
    AllowanceOperatorHarness harness;
    AllowanceHandler handler;

    function setUp() public {
        harness = new AllowanceOperatorHarness();
        harness.initialize();
        handler = new AllowanceHandler(harness);
        targetContract(address(handler));
    }

    function invariant_LedgerBalancesMatchExpectation() external view {
        uint256 len = handler.accountsLength();
        for (uint256 i = 0; i < len; i++) {
            address account = handler.accountAt(i);
            assertEq(
                ILedgerVerifiable(address(harness)).getLedgerBalance(account, handler.token()),
                handler.expectedLedger(account),
                "Ledger balance mismatch"
            );
        }
    }

    function invariant_AllowancesMatchExpectation() external view {
        uint256 len = handler.accountsLength();
        for (uint256 i = 0; i < len; i++) {
            address from = handler.accountAt(i);
            for (uint256 j = 0; j < len; j++) {
                address to = handler.accountAt(j);
                if (from == to) continue;
                assertEq(
                    harness.getApprovedAmount(from, to, handler.token()),
                    handler.expectedAllowance(from, to),
                    "Allowance mismatch"
                );
            }
        }
    }
}
