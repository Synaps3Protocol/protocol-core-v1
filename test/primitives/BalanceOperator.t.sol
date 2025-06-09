// test balanaceoperator here// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ILedgerVerifiable } from "contracts/core/interfaces/base/ILedgerVerifiable.sol";
import { IBalanceDepositor } from "contracts/core/interfaces/base/IBalanceDepositor.sol";
import { IBalanceVerifiable } from "contracts/core/interfaces/base/IBalanceVerifiable.sol";
import { IBalanceTransferable } from "contracts/core/interfaces/base/IBalanceTransferable.sol";
import { IBalanceWithdrawable } from "contracts/core/interfaces/base/IBalanceWithdrawable.sol";
import { BalanceOperatorUpgradeable } from "contracts/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";

contract BalanceOperatorWrapper is BalanceOperatorUpgradeable {}

contract BalanceOperatorTest is BaseTest {
    address op;

    function setUp() public initialize {
        deployToken();
        op = address(new BalanceOperatorWrapper());
    }

    function test_Deposit_ValidDeposit() public {
        // 100 MMC
        uint256 amount = 100 * 1e18;
        vm.startPrank(admin);
        uint256 prevBalance = IERC20(token).balanceOf(admin);
        uint256 confirmed = _validDeposit(admin, amount);
        uint256 afterBalance = IERC20(token).balanceOf(admin);

        uint256 balance = ILedgerVerifiable(op).getLedgerBalance(admin, token);
        uint256 contractBalance = IBalanceVerifiable(op).getBalance(token);
        vm.stopPrank();

        assertEq(confirmed, balance, "Confirmed amount should match ledger balance");
        assertEq(contractBalance, confirmed, "Contract balance should match confirmed amount");
        assertEq(afterBalance, prevBalance - confirmed, "Admin balance should decrease by confirmed amount");
    }

    function test_Deposit_FundsDepositedEventEmitted() public {
        uint256 amount = 100 * 1e18;
        vm.startPrank(admin);
        IERC20(token).approve(op, amount);
        vm.expectEmit(true, true, false, true, address(op));
        emit IBalanceDepositor.FundsDeposited(admin, admin, amount, token);
        IBalanceDepositor(op).deposit(admin, amount, token);
        vm.stopPrank();
    }

    function test_Deposit_RevertWhen_InvalidApproval() public {
        vm.expectRevert(abi.encodeWithSignature("FailDuringDeposit(string)", "Amount exceeds allowance."));
        IBalanceDepositor(op).deposit(admin, 100 * 1e18, token);
    }

    function test_Deposit_RevertIf_InvalidParams() public {
        uint256 amount = 0;
        address account = address(0);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));
        // must fail if account = address(0) or amount == 0
        vm.expectRevert(err);
        IBalanceDepositor(op).deposit(admin, amount, token);

        vm.expectRevert(err);
        IBalanceDepositor(op).deposit(account, 1 * 1e18, token);
    }

    function test_Withdraw_ValidWithdraw() public {
        // 100 MMC
        uint256 amount = 100 * 1e18;
        vm.startPrank(admin);
        uint256 prevBalance = IERC20(token).balanceOf(admin);
        uint256 deposited = _validDeposit(admin, amount);
        uint256 afterBalance = IERC20(token).balanceOf(admin);

        uint256 confirmed = IBalanceWithdrawable(op).withdraw(admin, deposited, token);
        uint256 balance = ILedgerVerifiable(op).getLedgerBalance(admin, token);
        uint256 contractBalance = IBalanceVerifiable(op).getBalance(token);
        vm.stopPrank();

        assertEq(confirmed, deposited, "Confirmed amount should match deposited amount");
        assertEq(prevBalance, afterBalance + confirmed, "Admin balance should increase by confirmed amount");
        assertEq(contractBalance, 0, "Contract balance should be zero after withdrawal");
        assertEq(balance, 0, "Ledger balance should be zero after withdrawal");
    }

    function test_Withdraw_FundsWithdrawnEventEmitted() public {
        uint256 amount = 100 * 1e18;
        vm.startPrank(admin);
        _validDeposit(admin, amount);

        vm.expectEmit(true, true, false, true, address(op));
        emit IBalanceWithdrawable.FundsWithdrawn(admin, admin, amount, token);
        IBalanceWithdrawable(op).withdraw(admin, amount, token);
        vm.stopPrank();
    }

    function test_Withdraw_RevertIf_NoFunds() public {
        vm.expectRevert(bytes4(keccak256("NoFundsToWithdraw()")));
        IBalanceWithdrawable(op).withdraw(admin, 1 * 1e18, token);
    }

    function test_Withdraw_RevertIf_InvalidParams() public {
        uint256 amount = 0;
        address account = address(0);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));
        // must fail if account = address(0) or amount == 0
        vm.expectRevert(err);
        IBalanceWithdrawable(op).withdraw(admin, amount, token);

        vm.expectRevert(err);
        IBalanceWithdrawable(op).withdraw(account, 1 * 1e18, token);
    }

    function test_Transfer_ValidTransfer() public {
        // 100 MMC
        uint256 amount = 100 * 1e18;
        uint256 expectedAfter = amount / 2;
        address user = vm.addr(7);

        vm.startPrank(admin);
        _validDeposit(admin, amount);
        // transfer the haft of the balance to user
        uint256 confirmed = IBalanceTransferable(op).transfer(user, expectedAfter, token);
        uint256 contractBalance = IBalanceVerifiable(op).getBalance(token);
        vm.stopPrank();

        ILedgerVerifiable verifier = ILedgerVerifiable(op);
        uint256 balanceAdmin = verifier.getLedgerBalance(admin, token);
        uint256 balanceUser = verifier.getLedgerBalance(user, token);

        assertEq(contractBalance, amount, "Contract balance should match initial deposit");
        assertEq(balanceAdmin, expectedAfter, "Admin balance should be half after transfer");
        assertEq(balanceUser, confirmed, "User balance should match transferred amount");
    }

    function test_Transfer_FundsTransferredEventEmitted() public {
        // 100 MMC
        uint256 amount = 100 * 1e18;
        address user = vm.addr(7);

        vm.startPrank(admin);
        _validDeposit(admin, amount);
        // transfer the haft of the balance to user
        vm.expectEmit(true, true, false, true, address(op));
        emit IBalanceTransferable.FundsTransferred(user, admin, amount, token);
        IBalanceTransferable(op).transfer(user, amount, token);
        vm.stopPrank();
    }

    function test_Transfer_RevertIf_NoFunds() public {
        vm.expectRevert(bytes4(keccak256("NoFundsToTransfer()")));
        IBalanceTransferable(op).transfer(vm.addr(7), 1 * 1e18, token);
    }

    function test_Transfer_RevertIf_InvalidParams() public {
        uint256 amount = 0;
        address account = address(0);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));
        // must fail if account = address(0) or amount == 0
        vm.expectRevert(err);
        IBalanceTransferable(op).transfer(admin, amount, token);

        vm.expectRevert(err);
        IBalanceTransferable(op).transfer(account, 1 * 1e18, token);

        vm.prank(admin);
        vm.expectRevert(err);
        // sender cannot be the recipient
        IBalanceTransferable(op).transfer(admin, 1 * 1e18, token);
    }

    function _validDeposit(address account, uint256 amount) private returns (uint256) {
        IERC20(token).approve(op, amount);
        return IBalanceDepositor(op).deposit(account, amount, token);
    }
}
