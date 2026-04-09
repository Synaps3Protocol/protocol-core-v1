// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { AccessControlledUpgradeable } from "contracts/core/primitives/upgradeable/AccessControlledUpgradeable.sol";

import { LedgerVault } from "contracts/financial/LedgerVault.sol";
import { ILedgerVerifiable } from "contracts/core/interfaces/base/ILedgerVerifiable.sol";
import { FinancialOps } from "contracts/core/libraries/FinancialOps.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LedgerVaultTest is BaseTest {
    LedgerVault internal vault;
    MockToken internal mockToken;

    address internal operator = vm.addr(11);
    address internal claimer = vm.addr(12);
    address internal other = vm.addr(13);

    function setUp() public initialize {
        mockToken = new MockToken();
        token = address(mockToken);

        deployLedgerVault();
        vault = LedgerVault(ledger);

        bytes4[] memory secSelectors = new bytes4[](2);
        secSelectors[0] = AccessControlledUpgradeable.pause.selector;
        secSelectors[1] = AccessControlledUpgradeable.unpause.selector;

        _setSecPermissions(ledger, secSelectors);
        _grantRole(C.OPS_ROLE, operator);
        _grantRole(C.OPS_ROLE, claimer);

        mockToken.mint(admin, 1_000_000 ether);
        mockToken.mint(user, 1_000_000 ether);
        mockToken.mint(other, 1_000_000 ether);
    }

    function _deposit(address account, uint256 amount) internal returns (uint256) {
        vm.startPrank(account);
        mockToken.approve(address(vault), amount);
        uint256 confirmed = vault.deposit(account, amount, address(mockToken));
        vm.stopPrank();
        return confirmed;
    }

    function test_Deposit_Succeeds() public {
        uint256 confirmed = _deposit(admin, 100 ether);

        assertEq(confirmed, 100 ether, "Deposit return mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(mockToken)),
            100 ether,
            "Ledger balance mismatch"
        );
        assertEq(mockToken.balanceOf(address(vault)), 100 ether, "Vault token balance mismatch");
    }

    function test_Deposit_RevertWhen_NoAllowance() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Amount exceeds allowance."));
        vault.deposit(admin, 10 ether, address(mockToken));
    }

    function test_Deposit_RevertWhen_CurrencyNotApproved() public {
        MockToken unapproved = new MockToken();
        unapproved.mint(admin, 100 ether);

        vm.startPrank(admin);
        unapproved.approve(address(vault), 10 ether);
        vm.expectRevert(abi.encodeWithSelector(LedgerVault.CurrencyNotAllowed.selector, address(unapproved)));
        vault.deposit(admin, 10 ether, address(unapproved));
        vm.stopPrank();
    }

    function test_Withdraw_Succeeds() public {
        _deposit(admin, 200 ether);

        vm.prank(admin);
        uint256 withdrawn = vault.withdraw(admin, 150 ether, address(mockToken));

        assertEq(withdrawn, 150 ether, "Withdrawn amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(mockToken)),
            50 ether,
            "Ledger balance after withdraw"
        );
        assertEq(mockToken.balanceOf(admin), 1_000_000 ether - 50 ether, "Admin token balance mismatch");
    }

    function test_Withdraw_RevertWhen_NoFunds() public {
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("NoFundsToWithdraw()")));
        vault.withdraw(admin, 1 ether, address(mockToken));
    }

    function test_Transfer_Succeeds() public {
        _deposit(admin, 100 ether);

        vm.prank(admin);
        uint256 moved = vault.transfer(user, 40 ether, address(mockToken));

        assertEq(moved, 40 ether, "Transfer amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(mockToken)),
            60 ether,
            "Admin ledger after transfer"
        );
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(mockToken)),
            40 ether,
            "User ledger after transfer"
        );
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(mockToken)) +
                ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(mockToken)),
            100 ether,
            "Ledger totals must conserve balance"
        );
    }

    function test_Transfer_RevertWhen_Self() public {
        _deposit(admin, 50 ether);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        vault.transfer(admin, 10 ether, address(mockToken));
    }

    function test_Lock_Succeeds() public {
        _deposit(user, 120 ether);

        vm.prank(operator);
        uint256 locked = vault.lock(user, 70 ether, address(mockToken));

        assertEq(locked, 70 ether, "Locked amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(mockToken)),
            50 ether,
            "User ledger after lock"
        );
        assertEq(vault.getLockedBalance(user, address(mockToken)), 70 ether, "Locked balance mismatch");
    }

    function test_Lock_RevertWhen_Insufficient() public {
        _deposit(user, 10 ether);

        vm.prank(operator);
        vm.expectRevert(bytes4(keccak256("NoFundsToLock()")));
        vault.lock(user, 20 ether, address(mockToken));
    }

    function test_Release_Succeeds() public {
        _deposit(user, 90 ether);
        vm.prank(operator);
        vault.lock(user, 60 ether, address(mockToken));

        vm.prank(operator);
        uint256 released = vault.release(user, 30 ether, address(mockToken));

        assertEq(released, 30 ether, "Released amount mismatch");
        assertEq(vault.getLockedBalance(user, address(mockToken)), 30 ether, "Locked balance after release");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(mockToken)),
            60 ether,
            "Ledger after release"
        );
    }

    function test_Claim_Succeeds() public {
        _deposit(user, 100 ether);
        vm.prank(operator);
        vault.lock(user, 40 ether, address(mockToken));

        vm.prank(claimer);
        uint256 claimed = vault.claim(user, 25 ether, address(mockToken));

        assertEq(claimed, 25 ether, "Claim amount mismatch");
        assertEq(vault.getLockedBalance(user, address(mockToken)), 15 ether, "Locked balance after claim");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(mockToken)),
            25 ether,
            "Claimer ledger after claim"
        );
    }

    function test_Lock_RevertWhen_Unauthorized() public {
        _deposit(user, 30 ether);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, user));
        vm.prank(user);
        vault.lock(user, 10 ether, address(mockToken));
    }

    function test_Claim_RevertWhen_Unauthorized() public {
        _deposit(user, 50 ether);
        vm.prank(operator);
        vault.lock(user, 20 ether, address(mockToken));

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, other));
        vm.prank(other);
        vault.claim(user, 5 ether, address(mockToken));
    }

    function test_Pause_BlocksStateChanging() public {
        _deposit(admin, 10 ether);
        vm.prank(sec);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vault.withdraw(admin, 1 ether, address(mockToken));

        vm.prank(sec);
        vault.unpause();

        vm.prank(admin);
        vault.withdraw(admin, 1 ether, address(mockToken));
    }

    function test_Integration_FullFlow() public {
        _deposit(user, 200 ether);
        vm.prank(operator);
        vault.lock(user, 120 ether, address(mockToken));
        vm.prank(claimer);
        vault.claim(user, 70 ether, address(mockToken));
        vm.prank(operator);
        vault.release(user, 30 ether, address(mockToken));
        vm.prank(user);
        vault.transfer(other, 40 ether, address(mockToken));

        assertEq(vault.getLockedBalance(user, address(mockToken)), 20 ether, "Remaining locked");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(mockToken)),
            70 ether,
            "User ledger after flow"
        );
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(mockToken)),
            70 ether,
            "Claimer ledger after flow"
        );
    }

    function test_DepositWithdraw_FullAmountRestoresState() public {
        uint256 amount = 250 ether;
        _deposit(user, amount);

        vm.prank(user);
        uint256 withdrawn = vault.withdraw(user, amount, address(mockToken));
        assertEq(withdrawn, amount, "Withdrawn amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(mockToken)),
            0,
            "Ledger balance should return to zero"
        );
        assertEq(mockToken.balanceOf(address(vault)), 0, "Vault should hold no tokens");
    }

    function test_LedgerAndLockedBalancesMatchVaultHoldings() public {
        _deposit(user, 300 ether);
        vm.prank(operator);
        vault.lock(user, 120 ether, address(mockToken));
        vm.prank(claimer);
        vault.claim(user, 40 ether, address(mockToken));
        vm.prank(operator);
        vault.release(user, 50 ether, address(mockToken));

        uint256 ledgerUser = ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(mockToken));
        uint256 ledgerClaimer = ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(mockToken));
        uint256 lockedUser = vault.getLockedBalance(user, address(mockToken));
        uint256 vaultBalance = mockToken.balanceOf(address(vault));

        assertEq(ledgerUser + ledgerClaimer + lockedUser, vaultBalance, "Vault balance must equal ledger + locked");
    }
}
