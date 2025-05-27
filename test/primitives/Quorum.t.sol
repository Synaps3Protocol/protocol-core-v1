// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { QuorumUpgradeable } from "contracts/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { IQuorumInspectable } from "contracts/core/interfaces/base/IQuorumInspectable.sol";
import { IQuorumRegistrable } from "contracts/core/interfaces/base/IQuorumRegistrable.sol";
import { IQuorumRevokable } from "contracts/core/interfaces/base/IQuorumRevokable.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

contract QuorumWrapper is QuorumUpgradeable {
    function status(uint256 entry) external view returns (uint8) {
        return uint8(_status(entry));
    }

    function revoke(uint256 entry) external {
        _revoke(entry);
    }

    function approve(uint256 entry) external {
        _approve(entry);
    }

    function quit(uint256 entry) external {
        _quit(entry);
    }

    function register(uint256 entry) external {
        _register(entry);
    }

    function reject(uint256 entry) external {
        _block(entry);
    }
}

contract QuorumTest is Test {
    address quorum;

    function setUp() public {
        quorum = address(new QuorumWrapper());
    }

    function test_DefaultStatus() public view {
        T.Status status = IQuorumInspectable(quorum).status(1234536789);
        assertTrue(status == T.Status.Pending);
    }

    function test_RegisterStatusFlow() public {
        uint256 entry = 1234567189;
        // initial pending status
        T.Status prevStatus = IQuorumInspectable(quorum).status(entry);
        assertTrue(prevStatus == T.Status.Pending);

        // register status
        IQuorumRegistrable(quorum).register(entry);
        T.Status newStatus = IQuorumInspectable(quorum).status(entry);
        assertTrue(newStatus == T.Status.Waiting);
    }

    function test_ActiveStatusFlow() public {
        uint256 entry = 1234526789;
        // waiting status -> active status
        IQuorumRegistrable(quorum).register(entry);
        IQuorumRegistrable(quorum).approve(entry);
        T.Status newStatus = IQuorumInspectable(quorum).status(entry);
        assertTrue(newStatus == T.Status.Active);
    }

    function test_QuitStatusFlow() public {
        uint256 entry = 1234256789;
        // waiting status -> pending status
        IQuorumRegistrable(quorum).register(entry);
        IQuorumRegistrable(quorum).quit(entry);
        T.Status newStatus = IQuorumInspectable(quorum).status(entry);
        assertTrue(newStatus == T.Status.Pending);
    }

    function test_BlockedStatusFlow() public {
        uint256 entry = 123455589;
        // waiting status -> blocked
        IQuorumRegistrable(quorum).register(entry);
        // blocked status happens before active
        IQuorumRegistrable(quorum).reject(entry);
        T.Status newStatus = IQuorumInspectable(quorum).status(entry);
        assertTrue(newStatus == T.Status.Blocked);
    }

    function test_RevokeStatusFlow() public {
        uint256 entry = 123455589;
        // waiting status -> active -> blocked
        IQuorumRegistrable(quorum).register(entry);
        IQuorumRegistrable(quorum).approve(entry);
        // revoked status happens after approved
        IQuorumRevokable(quorum).revoke(entry);
        T.Status newStatus = IQuorumInspectable(quorum).status(entry);
        assertTrue(newStatus == T.Status.Blocked);
    }

    function test_Approve_RevertWhen_ApproveNotRegistered() public {
        uint256 entry = 123456789;
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        IQuorumRegistrable(quorum).approve(entry);
    }

    function test_Register_RevertWhen_WaitingApproval() public {
        uint256 entry = 123456789;
        IQuorumRegistrable(quorum).register(entry);
        vm.expectRevert(QuorumUpgradeable.NotPendingApproval.selector);
        IQuorumRegistrable(quorum).register(entry);
    }

    function test_Revoke_RevertWhen_BlockedNotActive() public {
        uint256 entry = 12345677;
        IQuorumRegistrable(quorum).register(entry);
        vm.expectRevert(QuorumUpgradeable.InvalidInactiveState.selector);
        IQuorumRevokable(quorum).revoke(entry);
    }

    function test_Quit_RevertWhen_QuitNotWaiting() public {
        uint256 entry = 123456459;
        // blocked status
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        IQuorumRegistrable(quorum).quit(entry);
    }

    function test_Quit_RevertWhen_Blocked() public {
        uint256 entry = 123456789;
        // waiting status
        IQuorumRegistrable(quorum).register(entry);
        IQuorumRegistrable(quorum).reject(entry);
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        IQuorumRegistrable(quorum).quit(entry);
    }
}
