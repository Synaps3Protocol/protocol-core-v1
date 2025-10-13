// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessControlledUpgradeable } from "contracts/core/primitives/upgradeable/AccessControlledUpgradeable.sol";

import { LedgerVault } from "contracts/financial/LedgerVault.sol";
import { C } from "contracts/core/primitives/Constants.sol";
import { ILedgerVerifiable } from "contracts/core/interfaces/base/ILedgerVerifiable.sol";
import { FinancialOps } from "contracts/core/libraries/FinancialOps.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LedgerVaultHarness is LedgerVault {
    bytes32 private constant LOCK_SLOT =
        0xece3ff917f3a3127e521e0c3f2f90ff09a3c8199be32f9b40bff79e776960800;

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

contract LedgerVaultTest is Test {
    LedgerVaultHarness vault;
    AccessManager manager;
    MockToken token;

    address admin = vm.addr(1);
    address operator = vm.addr(2);
    address claimer = vm.addr(3);
    address user = vm.addr(4);
    address other = vm.addr(5);

    function setUp() public {
        token = new MockToken();
        manager = new AccessManager(admin);

        LedgerVaultHarness implementation = new LedgerVaultHarness();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSignature("initialize(address)", address(manager))
        );
        vault = LedgerVaultHarness(address(proxy));

        vm.startPrank(admin);
        bytes4[] memory adminSelectors = new bytes4[](2);
        adminSelectors[0] = AccessControlledUpgradeable.pause.selector;
        adminSelectors[1] = AccessControlledUpgradeable.unpause.selector;
        manager.setTargetFunctionRole(address(vault), adminSelectors, C.ADMIN_ROLE);

        bytes4[] memory opsSelectors = new bytes4[](3);
        opsSelectors[0] = LedgerVault.lock.selector;
        opsSelectors[1] = LedgerVault.release.selector;
        opsSelectors[2] = LedgerVault.claim.selector;
        manager.setTargetFunctionRole(address(vault), opsSelectors, C.OPS_ROLE);
        manager.setRoleAdmin(C.OPS_ROLE, C.ADMIN_ROLE);
        manager.grantRole(C.OPS_ROLE, operator, 0);
        manager.grantRole(C.OPS_ROLE, claimer, 0);
        vm.stopPrank();

        token.mint(admin, 1_000_000 ether);
        token.mint(user, 1_000_000 ether);
        token.mint(other, 1_000_000 ether);
    }

    function _deposit(address account, uint256 amount) internal returns (uint256) {
        vm.startPrank(account);
        token.approve(address(vault), amount);
        uint256 confirmed = vault.deposit(account, amount, address(token));
        vm.stopPrank();
        return confirmed;
    }

    function test_Deposit_Succeeds() public {
        uint256 confirmed = _deposit(admin, 100 ether);

        assertEq(confirmed, 100 ether, "Deposit return mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(token)),
            100 ether,
            "Ledger balance mismatch"
        );
        assertEq(token.balanceOf(address(vault)), 100 ether, "Vault token balance mismatch");
    }

    function test_Deposit_RevertWhen_NoAllowance() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(FinancialOps.FailDuringDeposit.selector, "Amount exceeds allowance."));
        vault.deposit(admin, 10 ether, address(token));
    }

    function test_Withdraw_Succeeds() public {
        _deposit(admin, 200 ether);

        vm.prank(admin);
        uint256 withdrawn = vault.withdraw(admin, 150 ether, address(token));

        assertEq(withdrawn, 150 ether, "Withdrawn amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(token)),
            50 ether,
            "Ledger balance after withdraw"
        );
        assertEq(token.balanceOf(admin), 1_000_000 ether - 50 ether, "Admin token balance mismatch");
    }

    function test_Withdraw_RevertWhen_NoFunds() public {
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("NoFundsToWithdraw()")));
        vault.withdraw(admin, 1 ether, address(token));
    }

    function test_Transfer_Succeeds() public {
        _deposit(admin, 100 ether);

        vm.prank(admin);
        uint256 moved = vault.transfer(user, 40 ether, address(token));

        assertEq(moved, 40 ether, "Transfer amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(token)),
            60 ether,
            "Admin ledger after transfer"
        );
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token)),
            40 ether,
            "User ledger after transfer"
        );
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(admin, address(token)) +
                ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token)),
            100 ether,
            "Ledger totals must conserve balance"
        );
    }

    function test_Transfer_RevertWhen_Self() public {
        _deposit(admin, 50 ether);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidOperationParameters()")));
        vault.transfer(admin, 10 ether, address(token));
    }

    function test_Lock_Succeeds() public {
        _deposit(user, 120 ether);

        vm.prank(operator);
        uint256 locked = vault.lock(user, 70 ether, address(token));

        assertEq(locked, 70 ether, "Locked amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token)),
            50 ether,
            "User ledger after lock"
        );
        assertEq(vault.lockedBalance(user, address(token)), 70 ether, "Locked balance mismatch");
    }

    function test_Lock_RevertWhen_Insufficient() public {
        _deposit(user, 10 ether);

        vm.prank(operator);
        vm.expectRevert(bytes4(keccak256("NoFundsToLock()")));
        vault.lock(user, 20 ether, address(token));
    }

    function test_Release_Succeeds() public {
        _deposit(user, 90 ether);
        vm.prank(operator);
        vault.lock(user, 60 ether, address(token));

        vm.prank(operator);
        uint256 released = vault.release(user, 30 ether, address(token));

        assertEq(released, 30 ether, "Released amount mismatch");
        assertEq(vault.lockedBalance(user, address(token)), 30 ether, "Locked balance after release");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token)),
            60 ether,
            "Ledger after release"
        );
    }

    function test_Claim_Succeeds() public {
        _deposit(user, 100 ether);
        vm.prank(operator);
        vault.lock(user, 40 ether, address(token));

        vm.prank(claimer);
        uint256 claimed = vault.claim(user, 25 ether, address(token));

        assertEq(claimed, 25 ether, "Claim amount mismatch");
        assertEq(vault.lockedBalance(user, address(token)), 15 ether, "Locked balance after claim");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(token)),
            25 ether,
            "Claimer ledger after claim"
        );
    }

    function test_Lock_RevertWhen_Unauthorized() public {
        _deposit(user, 30 ether);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, user));
        vm.prank(user);
        vault.lock(user, 10 ether, address(token));
    }

    function test_Claim_RevertWhen_Unauthorized() public {
        _deposit(user, 50 ether);
        vm.prank(operator);
        vault.lock(user, 20 ether, address(token));

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, other));
        vm.prank(other);
        vault.claim(user, 5 ether, address(token));
    }

    function test_Pause_BlocksStateChanging() public {
        _deposit(admin, 10 ether);
        vm.prank(admin);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vault.withdraw(admin, 1 ether, address(token));

        vm.prank(admin);
        vault.unpause();

        vm.prank(admin);
        vault.withdraw(admin, 1 ether, address(token));
    }

    function test_Integration_FullFlow() public {
        _deposit(user, 200 ether);
        vm.prank(operator);
        vault.lock(user, 120 ether, address(token));
        vm.prank(claimer);
        vault.claim(user, 70 ether, address(token));
        vm.prank(operator);
        vault.release(user, 30 ether, address(token));
        vm.prank(user);
        vault.transfer(other, 40 ether, address(token));

        assertEq(vault.lockedBalance(user, address(token)), 20 ether, "Remaining locked");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token)),
            70 ether,
            "User ledger after flow"
        );
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(token)),
            70 ether,
            "Claimer ledger after flow"
        );
    }

    function test_DepositWithdraw_FullAmountRestoresState() public {
        uint256 amount = 250 ether;
        _deposit(user, amount);

        vm.prank(user);
        uint256 withdrawn = vault.withdraw(user, amount, address(token));
        assertEq(withdrawn, amount, "Withdrawn amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token)),
            0,
            "Ledger balance should return to zero"
        );
        assertEq(token.balanceOf(address(vault)), 0, "Vault should hold no tokens");
    }

    function test_LedgerAndLockedBalancesMatchVaultHoldings() public {
        _deposit(user, 300 ether);
        vm.prank(operator);
        vault.lock(user, 120 ether, address(token));
        vm.prank(claimer);
        vault.claim(user, 40 ether, address(token));
        vm.prank(operator);
        vault.release(user, 50 ether, address(token));

        uint256 ledgerUser = ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token));
        uint256 ledgerClaimer = ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(token));
        uint256 lockedUser = vault.lockedBalance(user, address(token));
        uint256 vaultBalance = token.balanceOf(address(vault));

        assertEq(ledgerUser + ledgerClaimer + lockedUser, vaultBalance, "Vault balance must equal ledger + locked");
    }
}
