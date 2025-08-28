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

contract BalanceOperator is BalanceOperatorUpgradeable {
    function deposit(address recipient, uint256 amount, address currency) external returns (uint256) {
        return _deposit(recipient, amount, currency);
    }

    function withdraw(address recipient, uint256 amount, address currency) external returns (uint256) {
        return _withdraw(recipient, amount, currency);
    }

    function transfer(address recipient, uint256 amount, address currency) external returns (uint256) {
        return _transfer(recipient, amount, currency);
    }
}

contract Handler is Test {
    IERC20 mmc;
    uint256 public total;
    address[] public actors;
    BalanceOperator operator;

    constructor(BalanceOperator op, address currency) {
        operator = op;
        mmc = IERC20(currency);

        for (uint256 i = 0; i < 10; i++) {
            address a = vm.addr(i + 1);
            actors.push(a); // exec as default admin and fund the authors
        }
    }

    function getActors() external view returns (address[] memory) {
        return actors;
    }

    function deposit(uint256 actorIndex, uint256 amount) external {
        vm.assume(actorIndex < actors.length);
        address a = actors[actorIndex];
        vm.assume(amount > 0 && amount < mmc.balanceOf(a));

        // as author
        vm.startPrank(a);
        mmc.approve(address(operator), amount);
        uint256 confirmed = operator.deposit(a, amount, address(mmc));
        total += confirmed;
        vm.stopPrank();
    }

    function withdraw(uint256 actorIndex, uint256 amount) external {
        vm.assume(actorIndex < actors.length);
        address a = actors[actorIndex];
        vm.assume(amount > 0 && amount < operator.getLedgerBalance(a, address(mmc)));

        // as author
        vm.prank(a);
        uint256 confirmed = operator.withdraw(a, amount, address(mmc));
        total -= confirmed;
    }

    function transfer(uint256 actorIndex, uint256 actorIndexB, uint256 amount) external {
        vm.assume(actorIndex < actors.length);
        vm.assume(actorIndexB < actors.length);
        vm.assume(actorIndex != actorIndexB);

        address a = actors[actorIndex];
        address b = actors[actorIndexB];
        vm.assume(amount > 0 && amount < operator.getLedgerBalance(a, address(mmc)));

        // as author
        vm.prank(a);
        operator.transfer(b, amount, address(mmc));
    }
}

contract BalanceOperatorTest is BaseTest {
    Handler handler;
    BalanceOperator operator;
    address opAddress;

    function setUp() public initialize {
        deployToken();
        operator = new BalanceOperator();
        handler = new Handler(operator, token);
        opAddress = address(operator);

        uint256 amount = 100 * 1e18;
        address[] memory actors = handler.getActors();
        uint256 actorsLen = actors.length;

        for (uint256 i = 0; i < actorsLen; i++) {
            vm.prank(admin); // the funds origin
            IERC20(token).transfer(address(actors[i]), amount);
        }

        targetContract(address(handler));
    }

    function invariant_GetBalance() external {
        assertEq(handler.total(), IBalanceVerifiable(opAddress).getBalance(token));
    }

    function invariant_BalanceMatchActorsBalance() external {
        uint256 totalByActor = 0;
        address[] memory actors = handler.getActors();
        uint256 actorsLen = actors.length;

        for (uint256 i = 0; i < actorsLen; i++) {
            // each deposit/withdraw move funds internally for each balance in the ledger
            totalByActor += ILedgerVerifiable(opAddress).getLedgerBalance(actors[i], token);
        }

        // the contract balance must match with the sum of all ledgers
        assertEq(totalByActor, IBalanceVerifiable(opAddress).getBalance(token));
    }

    function test_Deposit_ValidDeposit() public {
        // 100 MMC
        uint256 amount = 100 * 1e18;
        vm.startPrank(admin);
        uint256 prevBalance = IERC20(token).balanceOf(admin);
        uint256 confirmed = _validDeposit(admin, amount);
        uint256 afterBalance = IERC20(token).balanceOf(admin);

        uint256 balance = ILedgerVerifiable(opAddress).getLedgerBalance(admin, token);
        uint256 contractBalance = IBalanceVerifiable(opAddress).getBalance(token);
        vm.stopPrank();

        assertEq(confirmed, balance, "Confirmed amount should match ledger balance");
        assertEq(contractBalance, confirmed, "Contract balance should match confirmed amount");
        assertEq(afterBalance, prevBalance - confirmed, "Admin balance should decrease by confirmed amount");
    }

    function test_Deposit_FundsDepositedEventEmitted() public {
        uint256 amount = 100 * 1e18;
        vm.startPrank(admin);
        IERC20(token).approve(opAddress, amount);

        vm.expectEmit(true, true, false, true, address(opAddress));
        emit IBalanceDepositor.FundsDeposited(admin, admin, amount, token);
        IBalanceDepositor(opAddress).deposit(admin, amount, token);
        vm.stopPrank();
    }

    function test_Deposit_RevertWhen_InvalidApproval() public {
        vm.expectRevert(abi.encodeWithSignature("FailDuringDeposit(string)", "Amount exceeds allowance."));
        IBalanceDepositor(opAddress).deposit(admin, 100 * 1e18, token);
    }

    function test_Deposit_RevertIf_InvalidParams() public {
        uint256 amount = 0;
        address account = address(0);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));
        // must fail if account = address(0) or amount == 0
        vm.expectRevert(err);
        IBalanceDepositor(opAddress).deposit(admin, amount, token);

        vm.expectRevert(err);
        IBalanceDepositor(opAddress).deposit(account, 1 * 1e18, token);
    }

    function test_Withdraw_ValidWithdraw() public {
        // 100 MMC
        uint256 amount = 100 * 1e18;
        vm.startPrank(admin);
        uint256 prevBalance = IERC20(token).balanceOf(admin);
        uint256 deposited = _validDeposit(admin, amount);
        uint256 afterBalance = IERC20(token).balanceOf(admin);

        uint256 confirmed = IBalanceWithdrawable(opAddress).withdraw(admin, deposited, token);
        uint256 balance = ILedgerVerifiable(opAddress).getLedgerBalance(admin, token);
        uint256 contractBalance = IBalanceVerifiable(opAddress).getBalance(token);
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

        vm.expectEmit(true, true, false, true, address(opAddress));
        emit IBalanceWithdrawable.FundsWithdrawn(admin, admin, amount, token);
        IBalanceWithdrawable(opAddress).withdraw(admin, amount, token);
        vm.stopPrank();
    }

    function test_Withdraw_RevertIf_NoFunds() public {
        vm.expectRevert(bytes4(keccak256("NoFundsToWithdraw()")));
        IBalanceWithdrawable(opAddress).withdraw(admin, 1 * 1e18, token);
    }

    function test_Withdraw_RevertIf_InvalidParams() public {
        uint256 amount = 0;
        address account = address(0);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));
        // must fail if account = address(0) or amount == 0
        vm.expectRevert(err);
        IBalanceWithdrawable(opAddress).withdraw(admin, amount, token);

        vm.expectRevert(err);
        IBalanceWithdrawable(opAddress).withdraw(account, 1 * 1e18, token);
    }

    function test_Transfer_ValidTransfer() public {
        // 100 MMC
        uint256 amount = 100 * 1e18;
        uint256 expectedAfter = amount / 2;
        address user = vm.addr(7);

        vm.startPrank(admin);
        _validDeposit(admin, amount);
        // transfer the haft of the balance to user
        uint256 confirmed = IBalanceTransferable(opAddress).transfer(user, expectedAfter, token);
        uint256 contractBalance = IBalanceVerifiable(opAddress).getBalance(token);
        vm.stopPrank();

        ILedgerVerifiable verifier = ILedgerVerifiable(opAddress);
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
        vm.expectEmit(true, true, false, true, address(opAddress));
        emit IBalanceTransferable.FundsTransferred(user, admin, amount, token);
        IBalanceTransferable(opAddress).transfer(user, amount, token);
        vm.stopPrank();
    }

    function test_Transfer_RevertIf_NoFunds() public {
        vm.expectRevert(bytes4(keccak256("NoFundsToTransfer()")));
        IBalanceTransferable(opAddress).transfer(vm.addr(7), 1 * 1e18, token);
    }

    function test_Transfer_RevertIf_InvalidParams() public {
        uint256 amount = 0;
        address account = address(0);
        bytes4 err = bytes4(keccak256("InvalidOperationParameters()"));
        // must fail if account = address(0) or amount == 0
        vm.expectRevert(err);
        IBalanceTransferable(opAddress).transfer(admin, amount, token);

        vm.expectRevert(err);
        IBalanceTransferable(opAddress).transfer(account, 1 * 1e18, token);

        vm.prank(admin);
        vm.expectRevert(err);
        // sender cannot be the recipient
        IBalanceTransferable(opAddress).transfer(admin, 1 * 1e18, token);
    }

    function _validDeposit(address account, uint256 amount) private returns (uint256) {
        IERC20(token).approve(opAddress, amount);
        return IBalanceDepositor(opAddress).deposit(account, amount, token);
    }
}
