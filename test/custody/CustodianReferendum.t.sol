// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { ICustodianVerifiable } from "contracts/core/interfaces/custody/ICustodianVerifiable.sol";
import { ICustodianRegistrable } from "contracts/core/interfaces/custody/ICustodianRegistrable.sol";
import { ICustodianInspectable } from "contracts/core/interfaces/custody/ICustodianInspectable.sol";
import { ICustodianRevokable } from "contracts/core/interfaces/custody/ICustodianRevokable.sol";
import { ICustodianFactory } from "contracts/core/interfaces/custody/ICustodianFactory.sol";

import { CustodianShared } from "test/shared/CustodianShared.t.sol";
import { CustodianReferendum } from "contracts/custody/CustodianReferendum.sol";
import { CustodianImpl } from "contracts/custody/CustodianImpl.sol";

contract CustodianReferendumTest is CustodianShared {
    /// ----------------------------------------------------------------

    function test_Register_RegisteredEventEmitted() public {
        address custodian = _deployCustodian("contentrider.com", user);
        // after register a custodian a Registered event is expected
        vm.warp(1641070803);
        vm.startPrank(admin);

        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Registered(custodian);
        ICustodianRegistrable(custodianReferendum).register(custodian);
        vm.stopPrank();
    }

    function test_Register_SetWaitingState() public {
        address custodian = _deployCustodian("contentrider.com", user);
        // register the custodian expecting the right status.
        ICustodianRegistrable(custodianReferendum).register(custodian);
        bool isWaiting = ICustodianVerifiable(custodianReferendum).isWaiting(custodian);
        assertTrue(isWaiting, "Custodian should be in waiting state");
    }

    function testFuzz_Register_RevertIf_InvalidCustodian(address custodian) public {
        vm.prank(admin); //
        vm.expectRevert(abi.encodeWithSignature("UnregisteredCustodian(address)", custodian));
        ICustodianRegistrable(custodianReferendum).register(custodian);
    }

    function test_Approve_ApprovedEventEmitted() public {
        address custodian = _deployCustodian("contentrider.com", user);
        _registerCustodian(custodian);

        vm.prank(nodesCouncil); // as governor.
        vm.warp(1641070802);
        // after register a custodian a Registered event is expected
        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Approved(custodian);
        ICustodianRegistrable(custodianReferendum).approve(custodian);
    }

    function test_Approve_SetActiveState() public {
        address custodian = _deployCustodian("contentrider.com", user);

        _registerAndApproveCustodian(custodian);
        bool isActive = ICustodianVerifiable(custodianReferendum).isActive(custodian);
        assertTrue(isActive, "Custodian should be active after approval");
    }

    function testFuzz_Approve_IncrementEnrollmentCount(uint256 rawN) public {
        uint256 n = bound(rawN, 1, 20);

        for (uint256 i = 0; i < n; i++) {
            address custodian = _deployCustodian(string.concat("content", vm.toString(i), ".com"), user);
            _registerAndApproveCustodian(custodian);
        }

        // valid approvals, increments the total of enrollments
        uint256 enrollment = ICustodianInspectable(custodianReferendum).getEnrollmentCount();
        assertEq(enrollment, n, "Enrollment count should be 3");
    }

    function test_Revoke_RevokedEventEmitted() public {
        address custodian = _deployCustodian("contentrider.com", user);
        _registerAndApproveCustodian(custodian); // still governor prank

        vm.prank(nodesCouncil);
        vm.warp(1641070801);
        // after register a custodian a Registered event is expected
        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Revoked(custodian);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
    }

    function test_Revoke_DecrementEnrollmentCount() public {
        address custodian = _deployCustodian("contentrider.com", user);
        _registerAndApproveCustodian(custodian); // still governor prank

        // valid approvals, increments the total of enrollments
        vm.prank(nodesCouncil);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
        uint256 enrollment = ICustodianInspectable(custodianReferendum).getEnrollmentCount();
        assertEq(enrollment, 0, "Enrollment count should be 0 after revocation");
    }

    function test_Revoke_SetBlockedState() public {
        address custodian = _deployCustodian("contentrider.com", user);
        _registerAndApproveCustodian(custodian); // still governor prank
        
        // custodian get revoked by governance..
        vm.prank(nodesCouncil);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
        bool isBlocked = ICustodianVerifiable(custodianReferendum).isBlocked(custodian);
        assertTrue(isBlocked, "Custodian should be blocked after revocation");
    }
}
