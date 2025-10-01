// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
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

    function testFuzz_DepositWithdraw(uint256 amount) public {
        amount = bound(amount, 1 ether, 1_000 ether);
        token.mint(user, amount);
        _deposit(user, amount);

        vm.prank(user);
        uint256 withdrawn = vault.withdraw(user, amount, address(token));
        assertEq(withdrawn, amount, "Withdrawn amount mismatch");
        assertEq(
            ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token)),
            0,
            "Ledger should be zero"
        );
    }

    function testFuzz_TransferMaintainsLedger(uint256 depositAmount, uint256 transferAmount) public {
        depositAmount = bound(depositAmount, 2 ether, 1_000 ether);
        transferAmount = bound(transferAmount, 1 ether, depositAmount - 1 ether);
        token.mint(user, depositAmount);
        _deposit(user, depositAmount);

        vm.prank(user);
        vault.transfer(other, transferAmount, address(token));

        uint256 ledgerUser = ILedgerVerifiable(address(vault)).getLedgerBalance(user, address(token));
        uint256 ledgerOther = ILedgerVerifiable(address(vault)).getLedgerBalance(other, address(token));
        assertEq(ledgerUser + ledgerOther, depositAmount, "Ledger conservation failed");
    }
}

contract LedgerVaultHandler is Test {
    LedgerVaultHarness public immutable vault;
    MockToken public immutable token;
    address public immutable operator;
    address public immutable claimer;
    address[] internal accounts;

    mapping(address => uint256) internal expectedLedger;
    mapping(address => uint256) internal expectedLocked;

    constructor(
        LedgerVaultHarness vault_,
        MockToken token_,
        address operator_,
        address claimer_,
        address[] memory actors
    ) {
        vault = vault_;
        token = token_;
        operator = operator_;
        claimer = claimer_;
        for (uint256 i = 0; i < actors.length; i++) {
            accounts.push(actors[i]);
        }
    }

    function accountsLength() external view returns (uint256) {
        return accounts.length;
    }

    function accountAt(uint256 idx) external view returns (address) {
        return accounts[idx];
    }

    function expectedLedgerOf(address account) external view returns (uint256) {
        return expectedLedger[account];
    }

    function expectedLockedOf(address account) external view returns (uint256) {
        return expectedLocked[account];
    }

    function _boundAmount(address account, uint256 amount) internal view returns (uint256) {
        uint256 balance = token.balanceOf(account);
        if (balance == 0) return 0;
        return bound(amount, 1, balance);
    }

    function deposit(uint256 idx, uint256 amount) external {
        vm.assume(idx < accounts.length);
        address account = accounts[idx];
        amount = _boundAmount(account, amount);
        if (amount == 0) return;

        vm.startPrank(account);
        token.approve(address(vault), amount);
        uint256 confirmed = vault.deposit(account, amount, address(token));
        vm.stopPrank();

        expectedLedger[account] += confirmed;
    }

    function withdraw(uint256 idx, uint256 amount) external {
        vm.assume(idx < accounts.length);
        address account = accounts[idx];
        uint256 available = expectedLedger[account];
        vm.assume(available > 0);
        amount = bound(amount, 1, available);

        vm.prank(account);
        uint256 confirmed = vault.withdraw(account, amount, address(token));
        expectedLedger[account] = available - confirmed;
    }

    function transfer(uint256 fromIdx, uint256 toIdx, uint256 amount) external {
        vm.assume(fromIdx < accounts.length && toIdx < accounts.length);
        vm.assume(fromIdx != toIdx);
        address from = accounts[fromIdx];
        address to = accounts[toIdx];
        uint256 available = expectedLedger[from];
        vm.assume(available > 0);
        amount = bound(amount, 1, available);

        vm.prank(from);
        vault.transfer(to, amount, address(token));

        expectedLedger[from] = available - amount;
        expectedLedger[to] += amount;
    }

    function lock(uint256 idx, uint256 amount) external {
        vm.assume(idx < accounts.length);
        address account = accounts[idx];
        uint256 available = expectedLedger[account];
        vm.assume(available > 0);
        amount = bound(amount, 1, available);

        vm.prank(operator);
        vault.lock(account, amount, address(token));

        expectedLedger[account] = available - amount;
        expectedLocked[account] += amount;
    }

    function release(uint256 idx, uint256 amount) external {
        vm.assume(idx < accounts.length);
        address account = accounts[idx];
        uint256 locked = expectedLocked[account];
        vm.assume(locked > 0);
        amount = bound(amount, 1, locked);

        vm.prank(operator);
        vault.release(account, amount, address(token));

        expectedLocked[account] = locked - amount;
        expectedLedger[account] += amount;
    }

    function claim(uint256 idx, uint256 amount) external {
        vm.assume(idx < accounts.length);
        address account = accounts[idx];
        uint256 locked = expectedLocked[account];
        vm.assume(locked > 0);
        amount = bound(amount, 1, locked);

        vm.prank(claimer);
        vault.claim(account, amount, address(token));

        expectedLocked[account] = locked - amount;
        expectedLedger[claimer] += amount;
    }
}

contract LedgerVaultInvariantTest is Test {
    LedgerVaultHarness vault;
    AccessManager manager;
    MockToken token;
    LedgerVaultHandler handler;

    address admin = vm.addr(11);
    address operator = vm.addr(12);
    address claimer = vm.addr(13);
    address[] accounts;

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

        accounts = new address[](5);
        for (uint256 i = 0; i < accounts.length; i++) {
            accounts[i] = vm.addr(20 + i);
            token.mint(accounts[i], 1_000_000 ether);
        }

        handler = new LedgerVaultHandler(vault, token, operator, claimer, accounts);
        targetContract(address(handler));
    }

    function _aggregateLedgerAndLocked()
        internal
        view
        returns (uint256 ledgerSum, uint256 lockedSum)
    {
        uint256 len = handler.accountsLength();
        for (uint256 i = 0; i < len; i++) {
            address account = handler.accountAt(i);
            ledgerSum += ILedgerVerifiable(address(vault)).getLedgerBalance(account, address(token));
            lockedSum += vault.lockedBalance(account, address(token));
            assertEq(
                handler.expectedLedgerOf(account),
                ILedgerVerifiable(address(vault)).getLedgerBalance(account, address(token)),
                "Ledger expectation mismatch"
            );
            assertEq(
                handler.expectedLockedOf(account),
                vault.lockedBalance(account, address(token)),
                "Locked expectation mismatch"
            );
        }

        ledgerSum += ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(token));
        lockedSum += vault.lockedBalance(claimer, address(token));
        assertEq(
            handler.expectedLedgerOf(claimer),
            ILedgerVerifiable(address(vault)).getLedgerBalance(claimer, address(token)),
            "Claimer ledger mismatch"
        );
        assertEq(
            handler.expectedLockedOf(claimer),
            vault.lockedBalance(claimer, address(token)),
            "Claimer locked mismatch"
        );
    }

    function invariant_LedgerAndLockedBalance() external view {
        (uint256 ledgerSum, uint256 lockedSum) = _aggregateLedgerAndLocked();
        assertEq(ledgerSum + lockedSum, token.balanceOf(address(vault)), "Ledger + locked must match vault balance");
    }
}
