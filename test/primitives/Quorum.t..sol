// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { QuorumUpgradeable } from "contracts/core/primitives/upgradeable/QuorumUpgradeable.sol";

contract QuorumTest is Test, QuorumUpgradeable {
    function test_DefaultStatus() public view {
        Status status = _status(1234536789);
        assertEq(uint(status), 0);
    }

    function test_RegisterStatusFlow() public {
        uint256 entry = 1234567189;
        // initial pending status
        Status status = _status(entry);
        assertEq(uint(status), 0);

        // register status
        _register(entry);
        Status waitingStatus = _status(entry);
        assertEq(uint(waitingStatus), 1);
    }

    function test_ActiveStatusFlow() public {
        uint256 entry = 1234526789;
        // waiting status
        _register(entry);
        // active status
        _approve(entry);
        Status activeStatus = _status(entry);
        assertEq(uint(activeStatus), 2);
    }

    function test_QuitStatusFlow() public {
        uint256 entry = 1234256789;
        // waiting status
        _register(entry);
        // pending status
        _quit(entry);
        Status activeStatus = _status(entry);
        assertEq(uint(activeStatus), 0);
    }

    function test_BlockedStatusFlow() public {
        uint256 entry = 123455589;
        // waiting status
        _register(entry);
        // active status
        _approve(entry);
        // blocked status
        _revoke(entry);
        Status blockedStatus = _status(entry);
        assertEq(uint(blockedStatus), 3);
    }

    function test_Approve_RevertWhen_ApproveNotRegistered() public {
        uint256 entry = 123456789;
        // active status
        vm.expectRevert(NotWaitingApproval.selector);
        _approve(entry);
    }

    function test_Revoke_RevertWhen_BlockedNotActive() public {
        vm.expectRevert(InvalidInactiveState.selector);
        uint256 entry = 12345677;
        // waiting status
        _register(entry);
        // blocked status
        _revoke(entry);
    }

    function test_Quit_RevertWhen_QuitNotWaiting() public {
        vm.expectRevert(NotWaitingApproval.selector);
        uint256 entry = 123456459;
        // blocked status
        _quit(entry);
    }
}
