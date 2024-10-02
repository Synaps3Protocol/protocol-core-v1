pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {QuorumUpgradeable} from "contracts/base/upgradeable/QuorumUpgradeable.sol";

/* The expected flow of these tests is:
 *
 *   Default (0: Pending)
 *      |
 *      v
 *   Register (1: Waiting)
 *      |               \
 *      v                v
 *   Quit (0: Pending)  Approve (2: Active)
 *                          |
 *                          v
 *                      Revoke (3: Blocked)
 */
contract QuorumTest is Test, QuorumUpgradeable {
    function test_DefaultStatus() public view {
        Status status = _status(123456789);
        assertEq(uint(status), 0);
    }

    function test_RegisterStatusFlow() public {
        uint256 entry = 123456789;
        // initial pending status
        Status status = _status(entry);
        assertEq(uint(status), 0);

        // register status
        _register(entry);
        Status waitingStatus = _status(entry);
        assertEq(uint(waitingStatus), 1);
    }

    function test_ActiveStatusFlow() public {
        uint256 entry = 123456789;
        // waiting status
        _register(entry);
        // active status
        _approve(entry);
        Status activeStatus = _status(entry);
        assertEq(uint(activeStatus), 2);
    }

    function test_QuitStatusFlow() public {
        uint256 entry = 123456789;
        // waiting status
        _register(entry);
        // pending status
        _quit(entry);
        Status activeStatus = _status(entry);
        assertEq(uint(activeStatus), 0);
    }

    function test_BlockedStatusFlow() public {
        uint256 entry = 123456789;
        // waiting status
        _register(entry);
        // active status
        _approve(entry);
        // blocked status
        _revoke(entry);
        Status blockedStatus = _status(entry);
        assertEq(uint(blockedStatus), 3);
    }

    function test_RevertWhen_ApproveNotRegisterd() public {
        vm.expectRevert(NotWaitingApproval.selector);
        uint256 entry = 123456789;
        // active status
        _approve(entry);
    }

    function test_RevertWhen_BlockedNotActive() public {
        vm.expectRevert(InvalidInactiveState.selector);
        uint256 entry = 123456789;
        // waiting status
        _register(entry);
        // blocked status
        _revoke(entry);
    }

    function test_RevertWhen_QuitNotWaiting() public {
        vm.expectRevert(NotWaitingApproval.selector);
        uint256 entry = 123456789;
        // blocked status
        _quit(entry);
    }
}
