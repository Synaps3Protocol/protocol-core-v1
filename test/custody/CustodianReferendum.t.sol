// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";


import { ICustodianVerifiable } from "contracts/core/interfaces/custody/ICustodianVerifiable.sol";
import { ICustodianExpirable } from "contracts/core/interfaces/custody/ICustodianExpirable.sol";
import { ICustodianRegistrable } from "contracts/core/interfaces/custody/ICustodianRegistrable.sol";
import { ICustodianInspectable } from "contracts/core/interfaces/custody/ICustodianInspectable.sol";
import { ICustodianRevokable } from "contracts/core/interfaces/custody/ICustodianRevokable.sol";
import { ICustodianFactory } from "contracts/core/interfaces/custody/ICustodianFactory.sol";

import { CustodianShared } from "test/shared/CustodianShared.t.sol";
import { CustodianReferendum } from "contracts/custody/CustodianReferendum.sol";
import { CustodianImpl } from "contracts/custody/CustodianImpl.sol";


contract CustodianReferendumTest is CustodianShared {
    /// ----------------------------------------------------------------

    function test_Init_ExpirationPeriod() public view {
        // test initialized treasury address
        uint256 expected = 180 days;
        uint256 period = ICustodianExpirable(custodianReferendum).getExpirationPeriod();
        assertEq(period, expected, "Expected expiration period should be 180 days");
    }

    function test_SetExpirationPeriod_ValidExpiration() public {
        uint256 expireIn = 3600; // seconds
        vm.prank(governor);
        ICustodianExpirable(custodianReferendum).setExpirationPeriod(expireIn);
        uint256 currentExpiration = ICustodianExpirable(custodianReferendum).getExpirationPeriod();
        assertEq(currentExpiration, expireIn, "Expected expiration period should match");
    }

    function test_SetExpirationPeriod_EmitPeriodSet() public {
        uint256 expireIn = 3600; // seconds
        vm.prank(governor);
        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.PeriodSet(expireIn);
        ICustodianExpirable(custodianReferendum).setExpirationPeriod(expireIn);
    }

    function test_SetExpirationPeriod_RevertWhen_Unauthorized() public {
        vm.expectRevert();
        ICustodianExpirable(custodianReferendum).setExpirationPeriod(10);
    }

    function test_Register_RegisteredEventEmitted() public {
        uint256 expectedFees = 100 * 1e18;
        address custodian = deployCustodian("contentrider.com");
        _setFeesAsGovernor(expectedFees); // free enrollment: test purpose
        // after register a custodian a Registered event is expected
        vm.warp(1641070803);
        vm.startPrank(admin);
        // approve fees payment: admin default account
        address[] memory parties = new address[](1);
        parties[0] = custodian;
        uint256 proof = _createAgreement(expectedFees, parties);

        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Registered(custodian, expectedFees);
        ICustodianRegistrable(custodianReferendum).register(proof, custodian);
        vm.stopPrank();
    }

    function test_Register_RevertIf_InvalidAgreement() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        address custodian = deployCustodian("contentrider.com");
        _setFeesAsGovernor(expectedFees);
        // expected revert if not valid allowance
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedEscrowAgent()"));
        ICustodianRegistrable(custodianReferendum).register(0, custodian);
    }

    function test_Register_SetValidEnrollmentTime() public {
        address custodian = deployCustodian("contentrider.com");
        ICustodianInspectable inspectable = ICustodianInspectable(custodianReferendum);
        ICustodianExpirable expirable = ICustodianExpirable(custodianReferendum);

        _setFeesAsGovernor(1 * 1e18);
        uint256 expectedExpiration = expirable.getExpirationPeriod();
        uint256 currentTime = 1727976358;
        vm.warp(currentTime); // set block.time to current time

        // register the custodian expecting the right enrollment time..
        _registerCustodianWithApproval(custodian, 1 * 1e18);
        uint256 expected = currentTime + expectedExpiration;
        uint256 got = inspectable.getEnrollmentDeadline(custodian);
        assertEq(got, expected, "Expected enrollment deadline should match");
    }

    function test_Register_SetWaitingState() public {
        _setFeesAsGovernor(1 * 1e18);
        address custodian = deployCustodian("contentrider.com");
        // register the custodian expecting the right status.
        _registerCustodianWithApproval(custodian, 1 * 1e18);
        bool isWaiting = ICustodianVerifiable(custodianReferendum).isWaiting(custodian);
        assertTrue(isWaiting, "Custodian should be in waiting state");
    }

    function test_Register_RevertIf_InvalidCustodian() public {
        vm.prank(user);
        address custodian = address(new CustodianImpl());

        vm.prank(admin); //
        vm.expectRevert(abi.encodeWithSignature("UnregisteredCustodian(address)", admin));
        ICustodianRegistrable(custodianReferendum).register(0, custodian);
    }

    function test_Approve_ApprovedEventEmitted() public {
        _setFeesAsGovernor(1 * 1e18);
        address custodian = deployCustodian("contentrider.com");
        _registerCustodianWithApproval(custodian, 1 * 1e18);

        vm.prank(governor); // as governor.
        vm.warp(1641070802);
        // after register a custodian a Registered event is expected
        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Approved(custodian);
        ICustodianRegistrable(custodianReferendum).approve(custodian);
    }

    function test_Approve_SetActiveState() public {
        address custodian = deployCustodian("contentrider.com");
        _registerAndApproveCustodian(custodian);
        bool isActive = ICustodianVerifiable(custodianReferendum).isActive(custodian);
        assertTrue(isActive, "Custodian should be active after approval");
    }

    function test_Approve_IncrementEnrollmentCount() public {
        address custodian = deployCustodian("contentrider.com");
        address custodian2 = deployCustodian("test2.com");
        address custodian3 = deployCustodian("test3.com");

        _registerAndApproveCustodian(custodian);
        _registerAndApproveCustodian(custodian2); // still governor prank
        _registerAndApproveCustodian(custodian3); // still governor prank

        // valid approvals, increments the total of enrollments
        uint256 enrollment = ICustodianInspectable(custodianReferendum).getEnrollmentCount();
        assertEq(enrollment, 3, "Enrollment count should be 3");
    }

    function test_Revoke_RevokedEventEmitted() public {
        address custodian = deployCustodian("contentrider.com");
        _registerAndApproveCustodian(custodian); // still governor prank
        vm.prank(governor);
        vm.warp(1641070801);
        // after register a custodian a Registered event is expected
        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Revoked(custodian);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
    }

    function test_Revoke_DecrementEnrollmentCount() public {
        address custodian = deployCustodian("contentrider.com");
        _registerAndApproveCustodian(custodian); // still governor prank
        // valid approvals, increments the total of enrollments
        vm.prank(governor);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
        uint256 enrollment = ICustodianInspectable(custodianReferendum).getEnrollmentCount();
        assertEq(enrollment, 0, "Enrollment count should be 0 after revocation");
    }

    function test_Revoke_SetBlockedState() public {
        address custodian = deployCustodian("contentrider.com");
        _registerAndApproveCustodian(custodian); // still governor prank
        // custodian get revoked by governance..
        vm.prank(governor);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
        bool isBlocked = ICustodianVerifiable(custodianReferendum).isBlocked(custodian);
        assertTrue(isBlocked, "Custodian should be blocked after revocation");
    }

   
}
