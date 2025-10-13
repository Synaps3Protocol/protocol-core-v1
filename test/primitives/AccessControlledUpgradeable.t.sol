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

    function test_AdminAction_AllowsOnlyAdmin() public {
        vm.prank(admin);
        uint256 result = harness.adminAction();
        assertEq(result, 1, "Admin action should increment counter");

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlledUpgradeable.InvalidUnauthorizedOperation.selector,
                "Only admin can perform this action."
            )
        );
        vm.prank(operator);
        harness.adminAction();
    }

    function test_OpsAction_AllowsOperator() public {
        vm.prank(operator);
        uint256 result = harness.opsAction();
        assertEq(result, 1, "Ops action should increment counter");

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stranger));
        vm.prank(stranger);
        harness.opsAction();
    }

    function test_PauseAndUnpauseControlOps() public {
        vm.prank(admin);
        harness.pause();
        assertTrue(harness.isPaused(), "Harness should be paused");

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(operator);
        harness.opsAction();

        vm.prank(admin);
        harness.unpause();
        assertFalse(harness.isPaused(), "Harness should be unpaused");

        vm.prank(operator);
        uint256 result = harness.opsAction();
        assertEq(result, 1, "Ops action should work after unpause");
    }

    function test_RoleAssignmentsVisible() public {
        assertTrue(harness.hasRoleView(C.ADMIN_ROLE, admin), "Admin should have admin role");
        assertTrue(harness.hasRoleView(C.OPS_ROLE, operator), "Operator should have ops role");

        vm.prank(admin);
        manager.revokeRole(C.OPS_ROLE, operator);
        assertFalse(harness.hasRoleView(C.OPS_ROLE, operator), "Operator role should be revoked");
    }

    function test_RolesCannotBeStolen() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlledUpgradeable.InvalidUnauthorizedOperation.selector,
                "Only admin can perform this action."
            )
        );
        vm.prank(stranger);
        harness.adminAction();

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, stranger));
        vm.prank(stranger);
        harness.opsAction();
    }
}
