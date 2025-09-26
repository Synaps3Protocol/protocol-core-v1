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
    QuorumUpgradeableHarness harness;

    function setUp() public {
        harness = new QuorumUpgradeableHarness();
        harness.initialize();
    }

    function test_DefaultStatusIsPending() public {
        assertEq(uint256(harness.statusOf(1)), uint256(T.Status.Pending), "Default should be pending");
    }

    function test_Register_FromPendingMovesToWaiting() public {
        harness.register(1);
        assertEq(uint256(harness.statusOf(1)), uint256(T.Status.Waiting), "Should move to waiting");
    }

    function test_Register_RevertWhen_NotPending() public {
        harness.register(1);
        vm.expectRevert(QuorumUpgradeable.NotPendingApproval.selector);
        harness.register(1);
    }

    function test_Approve_FromWaitingMovesToActive() public {
        harness.register(1);
        harness.approve(1);
        assertEq(uint256(harness.statusOf(1)), uint256(T.Status.Active), "Should be active");
    }

    function test_Approve_RevertWhen_NotWaiting() public {
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        harness.approve(1);
    }

    function test_Block_FromWaitingMovesToBlocked() public {
        harness.register(1);
        harness.blockEntry(1);
        assertEq(uint256(harness.statusOf(1)), uint256(T.Status.Blocked), "Should be blocked");
    }

    function test_Block_RevertWhen_NotWaiting() public {
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        harness.blockEntry(1);
    }

    function test_Quit_FromWaitingReturnsPending() public {
        harness.register(1);
        harness.quit(1);
        assertEq(uint256(harness.statusOf(1)), uint256(T.Status.Pending), "Should return to pending");
    }

    function test_Quit_RevertWhen_NotWaiting() public {
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        harness.quit(1);
    }

    function test_Revoke_FromActiveMovesToBlocked() public {
        harness.register(1);
        harness.approve(1);
        harness.revoke(1);
        assertEq(uint256(harness.statusOf(1)), uint256(T.Status.Blocked), "Active should move to blocked");
    }

    function test_Revoke_RevertWhen_NotActive() public {
        vm.expectRevert(QuorumUpgradeable.InvalidInactiveState.selector);
        harness.revoke(1);
    }

    function testFuzz_RegisterApproveCycle(uint256 entry) public {
        entry = bound(entry, 0, type(uint64).max);

        harness.register(entry);
        assertEq(uint256(harness.statusOf(entry)), uint256(T.Status.Waiting));

        harness.approve(entry);
        assertEq(uint256(harness.statusOf(entry)), uint256(T.Status.Active));
    }

    function testFuzz_RegisterQuitKeepsPending(uint256 entry) public {
        entry = bound(entry, 0, type(uint64).max);

        harness.register(entry);
        harness.quit(entry);

        assertEq(uint256(harness.statusOf(entry)), uint256(T.Status.Pending));
    }
}

contract QuorumHandler is Test {
    QuorumUpgradeableHarness public immutable harness;

    struct EntryState {
        bool tracked;
        T.Status status;
    }

    mapping(uint256 => EntryState) private _entries;
    uint256[] private _trackedEntries;

    constructor(QuorumUpgradeableHarness harness_) {
        harness = harness_;
    }

    function register(uint256 entry) external {
        entry = _normalize(entry);
        if (harness.statusOf(entry) != T.Status.Pending) return;
        harness.register(entry);
        _update(entry, T.Status.Waiting);
    }

    function approve(uint256 entry) external {
        entry = _normalize(entry);
        if (harness.statusOf(entry) != T.Status.Waiting) return;
        harness.approve(entry);
        _update(entry, T.Status.Active);
    }

    function quit(uint256 entry) external {
        entry = _normalize(entry);
        if (harness.statusOf(entry) != T.Status.Waiting) return;
        harness.quit(entry);
        _update(entry, T.Status.Pending);
    }

    function blockEntry(uint256 entry) external {
        entry = _normalize(entry);
        if (harness.statusOf(entry) != T.Status.Waiting) return;
        harness.blockEntry(entry);
        _update(entry, T.Status.Blocked);
    }

    function revoke(uint256 entry) external {
        entry = _normalize(entry);
        if (harness.statusOf(entry) != T.Status.Active) return;
        harness.revoke(entry);
        _update(entry, T.Status.Blocked);
    }

    function trackedLength() external view returns (uint256) {
        return _trackedEntries.length;
    }

    function trackedAt(uint256 index) external view returns (uint256) {
        return _trackedEntries[index];
    }

    function expectedStatus(uint256 entry) external view returns (T.Status) {
        return _entries[entry].status;
    }

    function _update(uint256 entry, T.Status newStatus) private {
        if (!_entries[entry].tracked) {
            _entries[entry].tracked = true;
            _trackedEntries.push(entry);
        }
        _entries[entry].status = newStatus;
    }

    function _normalize(uint256 entry) private pure returns (uint256) {
        return entry % 1_000;
    }
}

contract QuorumUpgradeableInvariantTest is Test {
    QuorumUpgradeableHarness harness;
    QuorumHandler handler;

    function setUp() public {
        harness = new QuorumUpgradeableHarness();
        harness.initialize();
        handler = new QuorumHandler(harness);
        targetContract(address(handler));
    }

    function invariant_StatusMatchesHandler() external view {
        uint256 len = handler.trackedLength();
        for (uint256 i = 0; i < len; i++) {
            uint256 entry = handler.trackedAt(i);
            assertEq(uint256(harness.statusOf(entry)), uint256(handler.expectedStatus(entry)), "Status mismatch");
        }
    }

    function invariant_StatusWithinEnum() external view {
        uint256 len = handler.trackedLength();
        for (uint256 i = 0; i < len; i++) {
            uint256 entry = handler.trackedAt(i);
            T.Status status = harness.statusOf(entry);
            assertTrue(
                status == T.Status.Pending ||
                    status == T.Status.Waiting ||
                    status == T.Status.Active ||
                    status == T.Status.Blocked,
                "Invalid status value"
            );
        }
    }
}

