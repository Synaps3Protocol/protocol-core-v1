pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ILedger } from "contracts/interfaces/ILedger.sol";
import { ITreasury } from "contracts/interfaces/economics/ITreasury.sol";
import { ITreasurer } from "contracts/interfaces/economics/ITreasurer.sol";
import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";
import { IGovernable } from "contracts/interfaces/IGovernable.sol";
import { IDistributorVerifiable } from "contracts/interfaces/syndication/IDistributorVerifiable.sol";
import { IDistributorExpirable } from "contracts/interfaces/syndication/IDistributorExpirable.sol";
import { IDistributorRegistrable } from "contracts/interfaces/syndication/IDistributorRegistrable.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { FeesHelper } from "contracts/libraries/FeesHelper.sol";
import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";
import { T } from "contracts/libraries/Types.sol";

contract DistributorReferendumTest is BaseTest {
    using FeesHelper for uint256;

    address distributor;
    address referendum;
    address tollgate;
    address treasury;
    address token;

    function setUp() public {
        token = deployToken();
        treasury = deployTreasury();
        tollgate = deployTollgate();
        referendum = deployDistributorReferendum(treasury, tollgate);
        distributor = deployDistributor("contentrider.com");
        setGovernorTo(tollgate);
        setGovernorTo(referendum);
    }

    function _setFeesAsGovernor(uint256 fees) internal {
        vm.startPrank(governor);
        T.Context syndication = T.Context.SYN;
        ITollgate(tollgate).setFees(syndication, fees, token);
        vm.stopPrank();
    }

    function _registerDistributorWithApproval(uint256 approval) internal {
        // manager = contract deployer
        // only manager can pay enrollment..
        vm.startPrank(admin);
        IERC20(token).approve(referendum, approval);
        IDistributorRegistrable(referendum).register(distributor, token);
        vm.stopPrank();
    }

    function _registerDistributorWithGovernorAndApproval() internal {
        uint256 expectedFees = 100 * 1e18;
        _setFeesAsGovernor(expectedFees);
        _registerDistributorWithApproval(expectedFees);
    }

    function _registerAndApproveDistributor() internal {
        // intially the balance = 0
        _setFeesAsGovernor(0);
        // register the distributor with fees = 100 MMC
        _registerDistributorWithApproval(0);
        vm.prank(governor); // as governor.
        // distribuitor approved only by governor..
        IDistributorRegistrable(referendum).approve(distributor);
    }

    /// ----------------------------------------------------------------

    function test_Init_TreasuryAddress() public view {
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

    function test_SetExpirationPeriod_RevertWhen_Unauthorized() public {
        vm.expectRevert();
        IDistributorExpirable(referendum).setExpirationPeriod(10);
    }

    function test_Disburse_ValidDisbursement() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        // 1-set enrollment fees.
        _setFeesAsGovernor(expectedFees);
        // 2-deploy and register contract
        _registerDistributorWithApproval(expectedFees);
        // get the expected disrbursement target
        address expectedTarget = ITreasury(treasury).getPoolAddress();

        // 3-after disburse funds to treasury a valid event should be emitted
        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true, address(referendum));
        emit ITreasurer.FeesDisbursed(expectedTarget, expectedFees, token);
        ITreasurer(referendum).disburse(token);
        vm.stopPrank();
        // zero after disburse all the balance
        assertEq(IERC20(token).balanceOf(referendum), 0);
    }

    function test_Register_RegisteredEventEmitted() public {
        _setFeesAsGovernor(0); // free enrollment: test purpose
        // after register a distributor a Registered event is expected
        vm.expectEmit(true, false, false, true, address(referendum));
        emit DistributorReferendum.Registered(distributor, 0);
        IDistributorRegistrable(referendum).register(distributor, token);
    }

    function test_Register_RevertIf_InvalidAllowance() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        _setFeesAsGovernor(expectedFees);
        // expected revert if not valid allowance
        vm.expectRevert(abi.encodeWithSignature("FailDuringTransfer(string)", "Invalid allowance."));
        IDistributorRegistrable(referendum).register(distributor, token);
    }

    function test_Register_SetValidEnrollmentTime() public {
        _setFeesAsGovernor(0);
        uint256 expectedExpiration = IDistributorExpirable(referendum).getExpirationPeriod();
        uint256 currentTime = 1727976358;
        vm.warp(currentTime); // set block.time to current time

        // register the distributor expecting the right enrollment time..
        _registerDistributorWithApproval(0);
        uint256 expected = currentTime + expectedExpiration;
        uint256 got = IDistributorRegistrable(referendum).getEnrollmentTime(distributor);
        assertEq(got, expected);
    }

    function test_Register_SetWaitingState() public {
        _setFeesAsGovernor(0);
        // register the distributor expecting the right status.
        _registerDistributorWithApproval(0);
        assertEq(IDistributorVerifiable(referendum).isWaiting(distributor), true);
    }

    function test_Register_RevertIf_InvalidDistributor() public {
        // register the distributor expecting the right status.
        vm.expectRevert(abi.encodeWithSignature("InvalidDistributorContract(address)", address(0)));
        IDistributorRegistrable(referendum).register(address(0), token);
    }


    // function test_Approve_ApprovedEventEmitted() public {
    //     // intially the balance = 0
    //     _setFeesAsGovernor(0);
    //     // register the distributor with fees = 100 MMC
    //     _registerDistributorWithApproval(0);

    //     vm.prank(governor); // as governor.
    //     // after register a distributor a Registered event is expected
    //     vm.expectEmit(true, true, false, false, address(referendum));
    //     emit Syndication.Approved(distributor);
    //     // distribuitor approved only by governor..
    //     ISyndicatableRegistrable(referendum).approve(distributor);
    // }

    // function test_Approve_SetZeroEnrollmentFees() public {
    //     // intially the balance = 0
    //     _registerAndApproveDistributor();
    //     assertEq(ILedger(referendum).getLedgerBalance(admin, token), 0);
    // }

    // function test_Approve_SetActiveState() public {
    //     _registerAndApproveDistributor();
    //     assertEq(ISyndicatableVerifiable(referendum).isActive(distributor), true);
    // }

    // function test_Approve_IncrementEnrollmentCount() public {
    //     _registerAndApproveDistributor();
    //     // valid approvals, increments the total of enrollments
    //     assertEq(ISyndicatableEnroller(referendum).getEnrollmentCount(), 1);
    // }

    // function test_Revoke_RevokedEventEmitted() public {
    //     // intially the balance = 0
    //     _registerAndApproveDistributor(); // still governor prank
    //     vm.prank(governor);
    //     // after register a distributor a Registered event is expected
    //     vm.expectEmit(true, true, false, false, address(referendum));
    //     emit Syndication.Revoked(distributor);
    //     // distribuitor get revoked by governance..
    //     ISyndicatableRevokable(referendum).revoke(distributor);
    // }

    // function test_Revoke_DecrementEnrollmentCount() public {
    //     _registerAndApproveDistributor(); // still governor prank
    //     // valid approvals, increments the total of enrollments
    //     vm.prank(governor);
    //     ISyndicatableRevokable(referendum).revoke(distributor);
    //     assertEq(ISyndicatableEnroller(referendum).getEnrollmentCount(), 0);
    // }

    // function test_Revoke_SetBlockedState() public {
    //     // intially the balance = 0
    //     _registerAndApproveDistributor(); // still governor prank
    //     // distribuitor get revoked by governance..
    //     vm.prank(governor);
    //     ISyndicatableRevokable(referendum).revoke(distributor);
    //     assertEq(ISyndicatableVerifiable(referendum).isBlocked(distributor), true);
    // }
}
