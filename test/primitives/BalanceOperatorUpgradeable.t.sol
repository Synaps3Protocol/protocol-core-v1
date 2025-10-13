// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { BalanceOperatorUpgradeable } from "contracts/core/primitives/upgradeable/BalanceOperatorUpgradeable.sol";
import { IBalanceDepositor } from "contracts/core/interfaces/base/IBalanceDepositor.sol";
import { IBalanceWithdrawable } from "contracts/core/interfaces/base/IBalanceWithdrawable.sol";
import { IBalanceTransferable } from "contracts/core/interfaces/base/IBalanceTransferable.sol";
import { IBalanceVerifiable } from "contracts/core/interfaces/base/IBalanceVerifiable.sol";
import { ILedgerVerifiable } from "contracts/core/interfaces/base/ILedgerVerifiable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MockToken is IERC20 {
    string public constant name = "MockToken";
    string public constant symbol = "MOCK";
    uint8 public constant decimals = 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "insufficient allowance");
        _allowances[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(to != address(0), "invalid to");
        require(_balances[from] >= amount, "insufficient balance");
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }
}

contract BalanceOperatorHarness is BalanceOperatorUpgradeable {
    function deposit(address recipient, uint256 amount, address currency) external payable returns (uint256) {
        return _deposit(recipient, amount, currency);
    }

    function withdraw(address recipient, uint256 amount, address currency) external returns (uint256) {
        return _withdraw(recipient, amount, currency);
    }

    function transfer(address recipient, uint256 amount, address currency) external returns (uint256) {
        return _transfer(recipient, amount, currency);
    }
}

contract BalanceOperatorUpgradeableTest is Test {
    BalanceOperatorHarness internal operator;
    MockToken internal token;
    address internal op;
    address internal alice;
    address internal bob;

    function setUp() public {
        operator = new BalanceOperatorHarness();
        token = new MockToken();
        op = address(operator);
        alice = vm.addr(1);
        bob = vm.addr(2);

        token.mint(alice, 1_000 ether);
        token.mint(bob, 500 ether);
    }

    function _deposit(address account, uint256 amount) internal returns (uint256) {
        vm.startPrank(account);
        token.approve(op, amount);
        uint256 confirmed = IBalanceDepositor(op).deposit(account, amount, address(token));
        vm.stopPrank();
        return confirmed;
    }

    function test_Deposit_UpdatesLedgerAndVault() public {
        uint256 amount = 200 ether;
        uint256 confirmed = _deposit(alice, amount);

        assertEq(confirmed, amount, "Confirmed amount mismatch");
        assertEq(
            ILedgerVerifiable(op).getLedgerBalance(alice, address(token)),
            amount,
            "Ledger should reflect deposit"
        );
        assertEq(IBalanceVerifiable(op).getBalance(address(token)), amount, "Vault balance mismatch");
        assertEq(token.balanceOf(alice), 800 ether, "Token balance should decrease");
    }

    function test_Deposit_RevertWhen_NoAllowance() public {
        vm.expectRevert(abi.encodeWithSignature("FailDuringDeposit(string)", "Amount exceeds allowance."));
        IBalanceDepositor(op).deposit(alice, 1 ether, address(token));
    }

    function test_Withdraw_ReturnsFundsAndClearsLedger() public {
        uint256 amount = 150 ether;
        _deposit(alice, amount);

        vm.prank(alice);
        uint256 withdrawn = IBalanceWithdrawable(op).withdraw(alice, amount, address(token));

        assertEq(withdrawn, amount, "Withdrawn amount mismatch");
        assertEq(ILedgerVerifiable(op).getLedgerBalance(alice, address(token)), 0, "Ledger should be zero");
        assertEq(IBalanceVerifiable(op).getBalance(address(token)), 0, "Vault balance should be zero");
        assertEq(token.balanceOf(alice), 1_000 ether, "Token balance should be restored");
    }

    function test_Withdraw_RevertWhen_InsufficientLedger() public {
        _deposit(alice, 10 ether);
        vm.expectRevert(bytes4(keccak256("NoFundsToWithdraw()")));
        vm.prank(alice);
        IBalanceWithdrawable(op).withdraw(alice, 20 ether, address(token));
    }

    function test_Transfer_MovesLedgerBalances() public {
        uint256 amount = 120 ether;
        _deposit(alice, amount);

        vm.prank(alice);
        uint256 moved = IBalanceTransferable(op).transfer(bob, 45 ether, address(token));

        assertEq(moved, 45 ether, "Transfer amount mismatch");
        ILedgerVerifiable ledger = ILedgerVerifiable(op);
        assertEq(ledger.getLedgerBalance(alice, address(token)), 75 ether, "Alice ledger mismatch");
        assertEq(ledger.getLedgerBalance(bob, address(token)), 45 ether, "Bob ledger mismatch");
        assertEq(
            ledger.getLedgerBalance(alice, address(token)) + ledger.getLedgerBalance(bob, address(token)),
            amount,
            "Ledger totals should conserve value"
        );
    }

    function test_Transfer_RevertWhen_SelfOrZero() public {
        _deposit(alice, 50 ether);

        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        vm.prank(alice);
        IBalanceTransferable(op).transfer(alice, 10 ether, address(token));

        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        vm.prank(alice);
        IBalanceTransferable(op).transfer(bob, 0, address(token));
    }

    function test_Integration_DepositTransferWithdraw() public {
        uint256 amount = 300 ether;
        _deposit(alice, amount);

        vm.prank(alice);
        IBalanceTransferable(op).transfer(bob, 100 ether, address(token));

        vm.prank(bob);
        uint256 withdrawnBob = IBalanceWithdrawable(op).withdraw(bob, 60 ether, address(token));
        vm.prank(alice);
        uint256 withdrawnAlice = IBalanceWithdrawable(op).withdraw(alice, 200 ether, address(token));

        ILedgerVerifiable ledger = ILedgerVerifiable(op);
        assertEq(withdrawnBob, 60 ether, "Bob withdrawal mismatch");
        assertEq(withdrawnAlice, 200 ether, "Alice withdrawal mismatch");
        assertEq(ledger.getLedgerBalance(alice, address(token)), 0, "Alice ledger should be zero");
        assertEq(ledger.getLedgerBalance(bob, address(token)), 40 ether, "Bob remaining ledger mismatch");
        assertEq(
            IBalanceVerifiable(op).getBalance(address(token)),
            40 ether,
            "Vault balance should equal remaining ledger"
        );
    }
}
