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

    function approve(address to, uint256 amount, address currency) external override returns (uint256) {
        return _approve(to, amount, currency);
    }

    function revoke(address to, uint256 amount, address currency) external override returns (uint256) {
        return _revoke(to, amount, currency);
    }

    function collect(address from, uint256 amount, address currency) external override returns (uint256) {
        return _collect(from, amount, currency);
    }

    function allowance(address owner, address spender, address currency) external view returns (uint256) {
        return getApprovedAmount(owner, spender, currency);
    }
}

contract AllowanceOperatorUpgradeableTest is Test {
    AllowanceOperatorHarness internal harness;
    address internal constant TOKEN = address(0xC0FFEE);
    address internal alice = vm.addr(1);
    address internal bob = vm.addr(2);
    address internal carol = vm.addr(3);

    function setUp() public {
        harness = new AllowanceOperatorHarness();
        harness.initialize();
    }

    function test_ApproveStoresAllowanceAndEmits() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(harness));
        emit IAllowanceApprovable.FundsApproved(alice, bob, 25 ether, TOKEN);
        harness.approve(bob, 25 ether, TOKEN);

        assertEq(harness.allowance(alice, bob, TOKEN), 25 ether, "Allowance mismatch");
    }

    function test_Approve_RevertWhen_InvalidParameters() public {
        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        harness.approve(address(0), 10, TOKEN);

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        harness.approve(bob, 0, TOKEN);

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        harness.approve(alice, 5, TOKEN);
    }

    function test_RevokeReducesAllowance() public {
        vm.startPrank(alice);
        harness.approve(bob, 40 ether, TOKEN);
        uint256 revoked = harness.revoke(bob, 15 ether, TOKEN);
        vm.stopPrank();

        assertEq(revoked, 15 ether, "Revoked amount mismatch");
        assertEq(harness.allowance(alice, bob, TOKEN), 25 ether, "Remaining allowance mismatch");
    }

    function test_Revoke_RevertWhen_InsufficientAllowance() public {
        vm.startPrank(alice);
        harness.approve(bob, 10 ether, TOKEN);
        vm.expectRevert(bytes4(keccak256("NoFundsToRevoke()")));
        harness.revoke(bob, 12 ether, TOKEN);
        vm.stopPrank();
    }

    function test_CollectTransfersLedgerBetweenAccounts() public {
        harness.boostLedger(alice, 60 ether, TOKEN);
        vm.prank(alice);
        harness.approve(bob, 45 ether, TOKEN);

        vm.expectEmit(true, true, false, true, address(harness));
        emit IAllowanceCollectable.FundsCollected(alice, bob, 30 ether, TOKEN);
        vm.prank(bob);
        harness.collect(alice, 30 ether, TOKEN);

        ILedgerVerifiable ledger = ILedgerVerifiable(address(harness));
        assertEq(harness.allowance(alice, bob, TOKEN), 15 ether, "Allowance should decrease");
        assertEq(ledger.getLedgerBalance(alice, TOKEN), 30 ether, "Alice ledger mismatch");
        assertEq(ledger.getLedgerBalance(bob, TOKEN), 30 ether, "Bob ledger mismatch");
    }

    function test_Collect_RevertWhen_NoAllowance() public {
        harness.boostLedger(alice, 20 ether, TOKEN);
        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NoFundsToCollect()")));
        harness.collect(alice, 10 ether, TOKEN);
    }

    function test_Collect_RevertWhen_InsufficientLedger() public {
        vm.prank(alice);
        harness.approve(bob, 10 ether, TOKEN);
        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("NoFundsToCollect()")));
        harness.collect(alice, 5 ether, TOKEN);
    }

    function test_Integration_ApproveCollectRevokeFlow() public {
        harness_boostAndApprove(alice, bob, 80 ether, 60 ether);
        harness_boostAndApprove(alice, carol, 80 ether, 15 ether);

        vm.prank(bob);
        harness.collect(alice, 30 ether, TOKEN);

        vm.prank(carol);
        harness.collect(alice, 10 ether, TOKEN);

        vm.startPrank(alice);
        harness.revoke(bob, 10 ether, TOKEN);
        vm.stopPrank();

        ILedgerVerifiable ledger = ILedgerVerifiable(address(harness));
        assertEq(ledger.getLedgerBalance(alice, TOKEN), 80 ether - 40 ether, "Alice residual ledger mismatch");
        assertEq(ledger.getLedgerBalance(bob, TOKEN), 30 ether, "Bob ledger mismatch");
        assertEq(ledger.getLedgerBalance(carol, TOKEN), 10 ether, "Carol ledger mismatch");
        assertEq(harness.allowance(alice, bob, TOKEN), 20 ether, "Bob allowance mismatch");
        assertEq(harness.allowance(alice, carol, TOKEN), 5 ether, "Carol allowance mismatch");
    }

    function harness_boostAndApprove(address owner, address spender, uint256 seedAmount, uint256 allowanceAmount) internal {
        ILedgerVerifiable ledger = ILedgerVerifiable(address(harness));
        uint256 currentBalance = ledger.getLedgerBalance(owner, TOKEN);
        if (currentBalance < seedAmount) {
            harness.boostLedger(owner, seedAmount - currentBalance, TOKEN);
        }
        vm.prank(owner);
        harness.approve(spender, allowanceAmount, TOKEN);
    }
}
