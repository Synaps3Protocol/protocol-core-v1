// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { QuorumUpgradeable } from "contracts/core/primitives/upgradeable/QuorumUpgradeable.sol";

contract QuorumWrapper is QuorumUpgradeable {
    function status(uint256 entry) external view returns (Status) {
        return _status(entry);
    }

    function revoke(uint256 entry) external {
        _revoke(entry);
    }

    function blocked(uint256 entry) external {
        _block(entry);
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
}

contract QuorumTest is Test {
    QuorumWrapper quorum;

    function setUp() public {
        quorum = new QuorumWrapper();
    }

    function test_DefaultStatus() public view {
        assertEq(uint(quorum.status(1234536789)), 0);
    }

    function test_RegisterStatusFlow() public {
        uint256 entry = 1234567189;
        // initial pending status
        assertEq(uint(quorum.status(entry)), 0);

        // register status
        quorum.register(entry);
        assertEq(uint(quorum.status(entry)), 1);
    }

    function test_ActiveStatusFlow() public {
        uint256 entry = 1234526789;
        // waiting status
        quorum.register(entry);
        // active status
        quorum.approve(entry);
        assertEq(uint(quorum.status(entry)), 2);
    }

    function test_QuitStatusFlow() public {
        uint256 entry = 1234256789;
        // waiting status
        quorum.register(entry);
        // pending status
        quorum.quit(entry);
        assertEq(uint(quorum.status(entry)), 0);
    }

    function test_BlockedStatusFlow() public {
        uint256 entry = 123455589;
        // waiting status
        quorum.register(entry);
        // active status
        quorum.approve(entry);
        // blocked status
        quorum.revoke(entry);
        assertEq(uint(quorum.status(entry)), 3);
    }

    function test_Approve_RevertWhen_ApproveNotRegistered() public {
        uint256 entry = 123456789;
        // active status
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        quorum.approve(entry);
    }

    function test_Revoke_RevertWhen_BlockedNotActive() public {
        uint256 entry = 12345677;
        // waiting status
        quorum.register(entry);
        // blocked status
        vm.expectRevert(QuorumUpgradeable.InvalidInactiveState.selector);
        quorum.revoke(entry);
    }

    function test_Quit_RevertWhen_QuitNotWaiting() public {
        uint256 entry = 123456459;
        // blocked status
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        quorum.quit(entry);
    }
}
