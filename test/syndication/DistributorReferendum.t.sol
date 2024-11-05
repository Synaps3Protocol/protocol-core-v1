// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ITreasury } from "contracts/interfaces/economics/ITreasury.sol";
import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";
import { IDistributorVerifiable } from "contracts/interfaces/syndication/IDistributorVerifiable.sol";
import { IDistributorExpirable } from "contracts/interfaces/syndication/IDistributorExpirable.sol";
import { IDistributorRegistrable } from "contracts/interfaces/syndication/IDistributorRegistrable.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";
import { T } from "contracts/libraries/Types.sol";

contract DistributorReferendumTest is BaseTest {
    address distributor;
    address referendum;
    address tollgate;
    address treasury;
    address token;

    function setUp() public {
        // setup the access manager..
        deployAndSetAccessManager();

        token = deployToken();
        treasury = deployTreasury();
        tollgate = deployTollgate();
        referendum = deployDistributorReferendum(treasury, tollgate);
        distributor = deployDistributor("contentrider.com");
    }

    /// ----------------------------------------------------------------

    function test_Init_ExpriationPeriod() public view {
        // test initialized treasury address
        uint256 expected = 180 days;
        uint256 period = IDistributorExpirable(referendum).getExpirationPeriod();
        assertEq(period, expected);
    }

    function test_SetExpirationPeriod_ValidExpiration() public {
        uint256 expireIn = 3600; // seconds
        vm.prank(governor);
        IDistributorExpirable(referendum).setExpirationPeriod(expireIn);
        assertEq(IDistributorExpirable(referendum).getExpirationPeriod(), expireIn);
    }

    function test_SetExpirationPeriod_EmitPeriodSet() public {
        uint256 expireIn = 3600; // seconds
        vm.prank(governor);
        vm.expectEmit(true, false, false, true, address(referendum));
        emit DistributorReferendum.PeriodSet(governor, expireIn);
        IDistributorExpirable(referendum).setExpirationPeriod(expireIn);
    }

    function test_SetExpirationPeriod_RevertWhen_Unauthorized() public {
        vm.expectRevert();
        IDistributorExpirable(referendum).setExpirationPeriod(10);
    }

    function test_Register_RegisteredEventEmitted() public {
        uint256 expectedFees = 100 * 1e18;
        _setFeesAsGovernor(expectedFees); // free enrollment: test purpose
        // after register a distributor a Registered event is expected
        vm.warp(1641070803);
        vm.startPrank(admin);
        // approve fees payment: admin default account
        IERC20(token).approve(referendum, expectedFees);
        vm.expectEmit(true, false, false, true, address(referendum));
        emit DistributorReferendum.Registered(distributor, 1641070803, expectedFees);
        IDistributorRegistrable(referendum).register(distributor, token);
        vm.stopPrank();
    }

    function test_Registrer_ValidFees() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        // 1-set enrollment fees.
        _setFeesAsGovernor(expectedFees);
        // 2-deploy and register contract
        _registerDistributorWithApproval(distributor, expectedFees);
        // zero after disburse all the balance
        assertEq(IERC20(token).balanceOf(referendum), expectedFees);
    }

    function test_Register_RevertIf_InvalidAllowance() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        _setFeesAsGovernor(expectedFees);
        // expected revert if not valid allowance
        vm.expectRevert(abi.encodeWithSignature("FailDuringDeposit(string)", "Amount exceeds allowance."));
        IDistributorRegistrable(referendum).register(distributor, token);
    }

    function test_Register_SetValidEnrollmentTime() public {
        IDistributorRegistrable registrable = IDistributorRegistrable(referendum);
        IDistributorExpirable expirable = IDistributorExpirable(referendum);

        _setFeesAsGovernor(1 * 1e18);
        uint256 expectedExpiration = expirable.getExpirationPeriod();
        uint256 currentTime = 1727976358;
        vm.warp(currentTime); // set block.time to current time

        // register the distributor expecting the right enrollment time..
        _registerDistributorWithApproval(distributor, 1 * 1e18);
        uint256 expected = currentTime + expectedExpiration;
        uint256 got = registrable.getEnrollmentDeadline(distributor);
        assertEq(got, expected);
    }

    function test_Register_SetWaitingState() public {
        _setFeesAsGovernor(1 * 1e18);
        // register the distributor expecting the right status.
        _registerDistributorWithApproval(distributor, 1 * 1e18);
        assertTrue(IDistributorVerifiable(referendum).isWaiting(distributor));
    }

    function test_Register_RevertIf_InvalidDistributor() public {
        // register the distributor expecting the right status.
        vm.expectRevert(abi.encodeWithSignature("InvalidDistributorContract(address)", address(0)));
        IDistributorRegistrable(referendum).register(address(0), token);
    }

    function test_Approve_ApprovedEventEmitted() public {
        _setFeesAsGovernor(1 * 1e18);
        _registerDistributorWithApproval(distributor, 1 * 1e18);

        vm.prank(governor); // as governor.
        vm.warp(1641070802);
        // after register a distributor a Registered event is expected
        vm.expectEmit(true, false, false, true, address(referendum));
        emit DistributorReferendum.Approved(distributor, 1641070802);
        // distribuitor approved only by governor..
        IDistributorRegistrable(referendum).approve(distributor);
    }

    function test_Approve_SetActiveState() public {
        _registerAndApproveDistributor(distributor);
        assertTrue(IDistributorVerifiable(referendum).isActive(distributor));
    }

    function test_Approve_IncrementEnrollmentCount() public {
        address distributor2 = deployDistributor("test2.com");
        address distributor3 = deployDistributor("test3.com");

        _registerAndApproveDistributor(distributor);
        _registerAndApproveDistributor(distributor2); // still governor prank
        _registerAndApproveDistributor(distributor3); // still governor prank

        // valid approvals, increments the total of enrollments
        assertEq(IDistributorRegistrable(referendum).getEnrollmentCount(), 3);
    }

    function test_Revoke_RevokedEventEmitted() public {
        _registerAndApproveDistributor(distributor); // still governor prank
        vm.prank(governor);
        vm.warp(1641070801);
        // after register a distributor a Registered event is expected
        vm.expectEmit(true, false, false, true, address(referendum));
        emit DistributorReferendum.Revoked(distributor, 1641070801);
        // distribuitor get revoked by governance..
        IDistributorRegistrable(referendum).revoke(distributor);
    }

    function test_Revoke_DecrementEnrollmentCount() public {
        _registerAndApproveDistributor(distributor); // still governor prank
        // valid approvals, increments the total of enrollments
        vm.prank(governor);
        IDistributorRegistrable(referendum).revoke(distributor);
        assertEq(IDistributorRegistrable(referendum).getEnrollmentCount(), 0);
    }

    function test_Revoke_SetBlockedState() public {
        _registerAndApproveDistributor(distributor); // still governor prank
        // distribuitor get revoked by governance..
        vm.prank(governor);
        IDistributorRegistrable(referendum).revoke(distributor);
        assertTrue(IDistributorVerifiable(referendum).isBlocked(distributor));
    }

    function _setFeesAsGovernor(uint256 fees) internal {
        vm.startPrank(governor);
        T.Context syndication = T.Context.SYN;
        ITollgate(tollgate).setFees(syndication, fees, token);
        vm.stopPrank();
    }

    function _registerDistributorWithApproval(address d9r, uint256 approval) internal {
        // manager = contract deployer
        // only manager can pay enrollment..
        vm.startPrank(admin);
        IERC20(token).approve(referendum, approval);
        IDistributorRegistrable(referendum).register(d9r, token);
        vm.stopPrank();
    }

    function _registerDistributorWithGovernorAndApproval() internal {
        uint256 expectedFees = 100 * 1e18;
        _setFeesAsGovernor(expectedFees);
        _registerDistributorWithApproval(distributor, expectedFees);
    }

    function _registerAndApproveDistributor(address d9r) internal {
        // intially the balance = 0
        _setFeesAsGovernor(1 * 1e18);
        // register the distributor with fees = 100 MMC
        _registerDistributorWithApproval(d9r, 1 * 1e18);
        vm.prank(governor); // as governor.
        // distribuitor approved only by governor..
        IDistributorRegistrable(referendum).approve(d9r);
    }
}
