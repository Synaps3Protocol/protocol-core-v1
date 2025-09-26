// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { AccessControlledUpgradeable } from "contracts/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract AccessControlledHarness is AccessControlledUpgradeable {
    uint256 public counter;

    function initialize(address manager) external initializer {
        __AccessControlled_init(manager);
    }

    function adminAction() external onlyAdmin returns (uint256) {
        counter += 1;
        return counter;
    }

    function opsAction() external restricted whenNotPaused returns (uint256) {
        counter += 1;
        return counter;
    }

    function isPaused() external view returns (bool) {
        return paused();
    }

    function hasRoleView(uint64 role, address account) external view returns (bool) {
        return _hasRole(role, account);
    }
}

contract AccessControlledUpgradeableTest is Test {
    AccessManager internal manager;
    AccessControlledHarness internal harness;

    address internal admin = vm.addr(1);
    address internal operator = vm.addr(2);
    address internal stranger = vm.addr(3);

    function setUp() public {
        manager = new AccessManager(admin);
        harness = new AccessControlledHarness();

        vm.prank(admin);
        harness.initialize(address(manager));

        vm.startPrank(admin);
        bytes4[] memory adminSelectors = new bytes4[](3);
        adminSelectors[0] = AccessControlledUpgradeable.pause.selector;
        adminSelectors[1] = AccessControlledUpgradeable.unpause.selector;
        adminSelectors[2] = AccessControlledHarness.adminAction.selector;
        manager.setTargetFunctionRole(address(harness), adminSelectors, C.ADMIN_ROLE);

        bytes4[] memory opsSelectors = new bytes4[](1);
        opsSelectors[0] = AccessControlledHarness.opsAction.selector;
        manager.setTargetFunctionRole(address(harness), opsSelectors, C.OPS_ROLE);
        manager.setRoleAdmin(C.OPS_ROLE, C.ADMIN_ROLE);
        manager.grantRole(C.OPS_ROLE, operator, 0);
        vm.stopPrank();
    }

    function test_Initialize_RevertWhen_InvalidManager() public {
        AccessControlledHarness fresh = new AccessControlledHarness();
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlledUpgradeable.InvalidUnauthorizedOperation.selector,
                "Invalid authority address."
            )
        );
        fresh.initialize(address(0));
    }

    function test_AdminAction_AllowsAdmin() public {
        vm.prank(admin);
        uint256 result = harness.adminAction();
        assertEq(result, 1, "Admin action should increment counter");
        assertEq(harness.counter(), 1, "Counter mismatch after admin action");
    }

    function test_AdminAction_RevertsForNonAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlledUpgradeable.InvalidUnauthorizedOperation.selector,
                "Only admin can perform this action."
            )
        );
        vm.prank(operator);
        harness.adminAction();
    }

    function test_HasRole_ReflectsAssignments() public {
        assertTrue(harness.hasRoleView(C.ADMIN_ROLE, admin), "Admin should have admin role");
        assertFalse(harness.hasRoleView(C.ADMIN_ROLE, operator), "Operator should not have admin role");

        vm.prank(admin);
        manager.grantRole(C.ADMIN_ROLE, operator, 0);

        assertTrue(harness.hasRoleView(C.ADMIN_ROLE, operator), "Operator admin role not reflected");
    }

    function test_OpsAction_AllowsOperator() public {
        vm.prank(operator);
        uint256 result = harness.opsAction();
        assertEq(result, 1, "Ops action should increment counter");
    }

    function test_OpsAction_RevertsForUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stranger));
        vm.prank(stranger);
        harness.opsAction();
    }

    function test_PauseBlocksOpsActionUntilUnpaused() public {
        vm.prank(admin);
        harness.pause();
        assertTrue(harness.isPaused(), "Contract should be paused");

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(operator);
        harness.opsAction();

        vm.prank(admin);
        harness.unpause();
        assertFalse(harness.isPaused(), "Contract should be unpaused");

        vm.prank(operator);
        uint256 result = harness.opsAction();
        assertEq(result, 1, "Ops action should succeed after unpause");
    }

    function test_Integration_GrantRevokeFlow() public {
        vm.prank(operator);
        harness.opsAction();
        assertEq(harness.counter(), 1, "Counter should increment after ops action");

        vm.prank(admin);
        manager.revokeRole(C.OPS_ROLE, operator);
        assertFalse(harness.hasRoleView(C.OPS_ROLE, operator), "Operator role should be revoked");

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, operator));
        vm.prank(operator);
        harness.opsAction();
    }

    function testFuzz_AdminAction_RevertsForNonAdmin(address caller) public {
        vm.assume(caller != admin && caller != address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlledUpgradeable.InvalidUnauthorizedOperation.selector,
                "Only admin can perform this action."
            )
        );
        vm.prank(caller);
        harness.adminAction();
    }

    function testFuzz_OpsAction_HonorsPause(bool pauseBeforeCall) public {
        if (pauseBeforeCall && !harness.isPaused()) {
            vm.prank(admin);
            harness.pause();
        }

        if (harness.isPaused()) {
            vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
            vm.prank(operator);
            harness.opsAction();

            vm.prank(admin);
            harness.unpause();
        } else {
            vm.prank(operator);
            harness.opsAction();
        }
    }
}

contract AccessControlledHandler is Test {
    AccessControlledHarness public immutable harness;
    AccessManager public immutable manager;
    address public immutable admin;
    address[] internal actors;

    uint256 internal expectedCounter;
    bool internal expectedPaused;

    constructor(AccessControlledHarness harness_, AccessManager manager_, address admin_, address[] memory actors_) {
        harness = harness_;
        manager = manager_;
        admin = admin_;

        for (uint256 i = 0; i < actors_.length; i++) {
            actors.push(actors_[i]);
        }
    }

    function grantOpsRole(uint256 actorIdx) external {
        vm.assume(actorIdx < actors.length);
        address actor = actors[actorIdx];
        vm.prank(admin);
        manager.grantRole(C.OPS_ROLE, actor, 0);
    }

    function revokeOpsRole(uint256 actorIdx) external {
        vm.assume(actorIdx < actors.length);
        address actor = actors[actorIdx];
        if (!harness.hasRoleView(C.OPS_ROLE, actor)) return;
        vm.prank(admin);
        manager.revokeRole(C.OPS_ROLE, actor);
    }

    function callAdminAction() external {
        vm.prank(admin);
        harness.adminAction();
        expectedCounter += 1;
    }

    function callOpsAction(uint256 actorIdx) external {
        vm.assume(actorIdx < actors.length);
        address actor = actors[actorIdx];
        if (!harness.hasRoleView(C.OPS_ROLE, actor) || harness.isPaused()) return;
        vm.prank(actor);
        harness.opsAction();
        expectedCounter += 1;
    }

    function pause() external {
        if (expectedPaused) return;
        vm.prank(admin);
        harness.pause();
        expectedPaused = true;
    }

    function unpause() external {
        if (!expectedPaused) return;
        vm.prank(admin);
        harness.unpause();
        expectedPaused = false;
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 idx) external view returns (address) {
        return actors[idx];
    }

    function expectedCounterValue() external view returns (uint256) {
        return expectedCounter;
    }

    function expectedPausedState() external view returns (bool) {
        return expectedPaused;
    }
}

contract AccessControlledInvariantTest is Test {
    AccessManager internal manager;
    AccessControlledHarness internal harness;
    AccessControlledHandler internal handler;

    address internal admin = vm.addr(11);
    address[] internal actors;

    function setUp() public {
        manager = new AccessManager(admin);
        harness = new AccessControlledHarness();

        vm.prank(admin);
        harness.initialize(address(manager));

        vm.startPrank(admin);
        bytes4[] memory adminSelectors = new bytes4[](3);
        adminSelectors[0] = AccessControlledUpgradeable.pause.selector;
        adminSelectors[1] = AccessControlledUpgradeable.unpause.selector;
        adminSelectors[2] = AccessControlledHarness.adminAction.selector;
        manager.setTargetFunctionRole(address(harness), adminSelectors, C.ADMIN_ROLE);

        bytes4[] memory opsSelectors = new bytes4[](1);
        opsSelectors[0] = AccessControlledHarness.opsAction.selector;
        manager.setTargetFunctionRole(address(harness), opsSelectors, C.OPS_ROLE);
        manager.setRoleAdmin(C.OPS_ROLE, C.ADMIN_ROLE);
        vm.stopPrank();

        actors = new address[](3);
        for (uint256 i = 0; i < actors.length; i++) {
            actors[i] = vm.addr(12 + i);
        }

        vm.prank(admin);
        manager.grantRole(C.OPS_ROLE, actors[0], 0);

        handler = new AccessControlledHandler(harness, manager, admin, actors);
        targetContract(address(handler));
    }

    function invariant_CounterMatchesExpectations() external view {
        assertEq(harness.counter(), handler.expectedCounterValue(), "Counter expectation mismatch");
    }

    function invariant_PauseStateMatches() external view {
        assertEq(harness.isPaused(), handler.expectedPausedState(), "Pause state mismatch");
    }

}
