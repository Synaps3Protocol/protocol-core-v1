// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { QuorumUpgradeable } from "contracts/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { T } from "contracts/core/primitives/Types.sol";

contract QuorumUpgradeableHarness is QuorumUpgradeable {
    function initialize() external initializer {
        __Quorum_init();
    }

    function statusOf(uint256 entry) external view returns (T.Status) {
        return _status(entry);
    }

    function register(uint256 entry) external {
        _register(entry);
    }

    function approve(uint256 entry) external {
        _approve(entry);
    }

    function blockEntry(uint256 entry) external {
        _block(entry);
    }

    function quit(uint256 entry) external {
        _quit(entry);
    }

    function revoke(uint256 entry) external {
        _revoke(entry);
    }
}

contract QuorumUpgradeableTest is Test {
    QuorumUpgradeableHarness internal harness;

    function setUp() public {
        harness = new QuorumUpgradeableHarness();
        harness.initialize();
    }

    function test_StatusDefaultsToPending() public {
        assertEq(uint256(harness.statusOf(1)), uint256(T.Status.Pending), "Default status should be pending");
    }

    function test_RegisterMovesToWaiting() public {
        harness.register(42);
        assertEq(uint256(harness.statusOf(42)), uint256(T.Status.Waiting), "Register should move to waiting");
    }

    function test_Register_RevertWhen_NotPending() public {
        harness.register(10);
        vm.expectRevert(QuorumUpgradeable.NotPendingApproval.selector);
        harness.register(10);
    }

    function test_ApproveMovesToActive() public {
        harness.register(7);
        harness.approve(7);
        assertEq(uint256(harness.statusOf(7)), uint256(T.Status.Active), "Approve should activate entry");
    }

    function test_Approve_RevertWhen_NotWaiting() public {
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        harness.approve(99);
    }

    function test_BlockMovesToBlocked() public {
        harness.register(5);
        harness.blockEntry(5);
        assertEq(uint256(harness.statusOf(5)), uint256(T.Status.Blocked), "Block should mark entry blocked");
    }

    function test_Block_RevertWhen_NotWaiting() public {
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        harness.blockEntry(12);
    }

    function test_QuitReturnsPending() public {
        harness.register(3);
        harness.quit(3);
        assertEq(uint256(harness.statusOf(3)), uint256(T.Status.Pending), "Quit should restore pending state");
    }

    function test_Quit_RevertWhen_NotWaiting() public {
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        harness.quit(4);
    }

    function test_RevokeMovesActiveToBlocked() public {
        harness.register(8);
        harness.approve(8);
        harness.revoke(8);
        assertEq(uint256(harness.statusOf(8)), uint256(T.Status.Blocked), "Revoke should block active entry");
    }

    function test_Revoke_RevertWhen_NotActive() public {
        vm.expectRevert(QuorumUpgradeable.InvalidInactiveState.selector);
        harness.revoke(6);
    }
}
