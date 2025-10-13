// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { FinancialOps } from "contracts/core/libraries/FinancialOps.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FinancialOpsHarness {
    using FinancialOps for address;

    function depositNative(uint256 amount) external payable returns (uint256) {
        return FinancialOps.safeDeposit(msg.sender, amount, address(0));
    }

    function depositToken(address from, uint256 amount, address token) external returns (uint256) {
        return FinancialOps.safeDeposit(from, amount, token);
    }

    function transferFunds(address to, uint256 amount, address token) external {
        FinancialOps.transfer(to, amount, token);
    }

    function increaseTokenAllowance(address spender, uint256 amount, address token) external {
        FinancialOps.increaseAllowance(spender, amount, token);
    }

    function queryAllowance(address owner, address token) external view returns (uint256) {
        return FinancialOps.allowance(owner, token);
    }

    function queryNativeAllowance(address owner) external payable returns (uint256) {
        return FinancialOps.allowance(owner, address(0));
    }

    function queryBalance(address target, address token) external view returns (uint256) {
        return FinancialOps.balanceOf(target, token);
    }

    receive() external payable {}
}

contract FinancialOpsTest is Test {
    FinancialOpsHarness internal harness;
    TestToken internal token;
    address internal alice;
    address internal bob;
    address internal carol;
    uint256 internal constant INITIAL_TOKEN_ALLOCATION = 1e24;
    uint256 internal constant INITIAL_NATIVE_ALLOCATION = 100 ether;

    function setUp() public {
        harness = new FinancialOpsHarness();
        token = new TestToken("Mock Token", "MOCK");
        alice = vm.addr(1);
        bob = vm.addr(2);
        carol = vm.addr(3);

        token.mint(alice, INITIAL_TOKEN_ALLOCATION);
        token.mint(bob, INITIAL_TOKEN_ALLOCATION);
        vm.deal(alice, INITIAL_NATIVE_ALLOCATION);
        vm.deal(bob, INITIAL_NATIVE_ALLOCATION);
    }

    function test_SafeDepositNative_Succeeds() public {
        uint256 amount = 5 ether;
        vm.prank(alice);
        uint256 deposited = harness.depositNative{ value: amount }(amount);
        assertEq(deposited, amount, "Deposit return mismatch");
        assertEq(address(harness).balance, amount, "Harness native balance mismatch");
    }

    function test_SafeDepositNative_RevertWhen_Mismatch() public {
        uint256 amount = 3 ether;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Invalid expected sent balance."));
        harness.depositNative{ value: amount - 1 }(amount);
    }

    function test_SafeDepositNative_RevertWhen_Zero() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Invalid amount or sender."));
        harness.depositNative{ value: 0 }(0);
    }

    function test_SafeDepositERC20_Succeeds() public {
        uint256 amount = 2e21;
        vm.startPrank(alice);
        token.approve(address(harness), amount);
        uint256 deposited = harness.depositToken(alice, amount, address(token));
        vm.stopPrank();

        assertEq(deposited, amount, "ERC20 deposit return mismatch");
        assertEq(token.balanceOf(address(harness)), amount, "Harness token balance mismatch");
        assertEq(token.balanceOf(alice), INITIAL_TOKEN_ALLOCATION - amount, "Alice token balance mismatch");
    }

    function test_SafeDepositERC20_RevertWhen_NoAllowance() public {
        uint256 amount = 1e18;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Amount exceeds allowance."));
        harness.depositToken(alice, amount, address(token));
    }

    function test_SafeDepositERC20_RevertWhen_Zero() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Invalid amount or sender."));
        harness.depositToken(alice, 0, address(token));
    }

    function test_TransferNative_Succeeds() public {
        uint256 amount = 6 ether;
        vm.prank(alice);
        harness.depositNative{ value: amount }(amount);

        uint256 transferAmount = 2 ether;
        uint256 bobBefore = bob.balance;
        harness.transferFunds(bob, transferAmount, address(0));

        assertEq(address(harness).balance, amount - transferAmount, "Harness native balance mismatch");
        assertEq(bob.balance, bobBefore + transferAmount, "Bob native balance mismatch");
    }

    function test_TransferERC20_Succeeds() public {
        uint256 amount = 1e22;
        vm.startPrank(alice);
        token.approve(address(harness), amount);
        harness.depositToken(alice, amount, address(token));
        vm.stopPrank();

        uint256 transferAmount = 3e21;
        uint256 bobBefore = token.balanceOf(bob);
        harness.transferFunds(bob, transferAmount, address(token));

        assertEq(token.balanceOf(address(harness)), amount - transferAmount, "Harness token balance mismatch");
        assertEq(token.balanceOf(bob), bobBefore + transferAmount, "Bob token balance mismatch");
    }

    function test_Transfer_RevertWhen_InvalidAmount() public {
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringTransfer.selector, "Invalid amount or recipient."));
        harness.transferFunds(address(0), 1, address(token));
    }

    function test_IncreaseAllowance_Succeeds() public {
        uint256 allowanceAmount = 5e20;
        harness.increaseTokenAllowance(carol, allowanceAmount, address(token));
        assertEq(token.allowance(address(harness), carol), allowanceAmount, "Allowance mismatch");
    }

    function test_IncreaseAllowance_RevertWhen_ZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Invalid spender or allowance attempt"));
        harness.increaseTokenAllowance(carol, 0, address(token));
    }

    function test_IncreaseAllowance_RevertWhen_NativeToken() public {
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Invalid spender or allowance attempt"));
        harness.increaseTokenAllowance(carol, 1, address(0));
    }

    function test_Allowance_NativeReflectsMsgValue() public {
        uint256 amount = 3 ether;
        uint256 reported = harness.queryNativeAllowance{ value: amount }(alice);
        assertEq(reported, amount, "Native allowance mismatch");
    }

    function test_Allowance_ERC20MatchesApproval() public {
        uint256 amount = 9e20;
        vm.startPrank(alice);
        token.approve(address(harness), amount);
        vm.stopPrank();

        uint256 reported = harness.queryAllowance(alice, address(token));
        assertEq(reported, amount, "Allowance report mismatch");
    }

    function test_BalanceOf_ReturnsBalances() public {
        uint256 nativeAmount = 2 ether;
        vm.prank(alice);
        harness.depositNative{ value: nativeAmount }(nativeAmount);

        uint256 tokenAmount = 3e21;
        vm.startPrank(bob);
        token.approve(address(harness), tokenAmount);
        harness.depositToken(bob, tokenAmount, address(token));
        vm.stopPrank();

        assertEq(harness.queryBalance(address(harness), address(0)), nativeAmount, "Native balance query mismatch");
        assertEq(harness.queryBalance(address(harness), address(token)), tokenAmount, "Token balance query mismatch");
    }

    function test_Integration_MultiActorFlow() public {
        vm.prank(alice);
        harness.depositNative{ value: 10 ether }(10 ether);
        vm.prank(bob);
        harness.depositNative{ value: 4 ether }(4 ether);

        vm.startPrank(alice);
        token.approve(address(harness), 5e21);
        harness.depositToken(alice, 5e21, address(token));
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(harness), 2e21);
        harness.depositToken(bob, 2e21, address(token));
        vm.stopPrank();

        harness.transferFunds(carol, 6 ether, address(0));
        harness.transferFunds(carol, 3e21, address(token));

        assertEq(address(harness).balance, 8 ether, "Harness native residual mismatch");
        assertEq(token.balanceOf(address(harness)), 4e21, "Harness token residual mismatch");
        assertEq(carol.balance, 6 ether, "Carol native balance mismatch");
        assertEq(token.balanceOf(carol), 3e21, "Carol token balance mismatch");
    }

    function test_DepositWithdrawFullyRestoresBalances() public {
        uint256 amount = 12 ether;
        vm.prank(alice);
        harness.depositNative{ value: amount }(amount);

        vm.prank(alice);
        harness.transferFunds(alice, amount, address(0));
        assertEq(address(harness).balance, 0, "Harness native balance should be zero");
    }

    function test_TokenDepositWithdrawFullyRestoresBalances() public {
        uint256 amount = 4e21;
        vm.startPrank(alice);
        token.approve(address(harness), amount);
        harness.depositToken(alice, amount, address(token));
        vm.stopPrank();

        harness.transferFunds(alice, amount, address(token));
        assertEq(token.balanceOf(address(harness)), 0, "Harness token balance should be zero");
    }
}
