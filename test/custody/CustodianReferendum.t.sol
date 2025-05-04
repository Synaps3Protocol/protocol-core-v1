// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ITreasury } from "contracts/core/interfaces/economics/ITreasury.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { ILedgerVault } from "contracts/core/interfaces/financial/ILedgerVault.sol";
import { IAgreementManager } from "contracts/core/interfaces/financial/IAgreementManager.sol";
import { ICustodianVerifiable } from "contracts/core/interfaces/custody/ICustodianVerifiable.sol";
import { ICustodianExpirable } from "contracts/core/interfaces/custody/ICustodianExpirable.sol";
import { ICustodianRegistrable } from "contracts/core/interfaces/custody/ICustodianRegistrable.sol";
import { ICustodianInspectable } from "contracts/core/interfaces/custody/ICustodianInspectable.sol";
import { ICustodianRevokable } from "contracts/core/interfaces/custody/ICustodianRevokable.sol";
import { ICustodianFactory } from "contracts/core/interfaces/custody/ICustodianFactory.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { CustodianReferendum } from "contracts/custody/CustodianReferendum.sol";
import { T } from "contracts/core/primitives/Types.sol";

contract CustodianReferendumTest is BaseTest {
    address custodian;

    function setUp() public initialize {
        deployCustodianReferendum();
        deployCustodianFactory();
        custodian = deployCustodian("contentrider.com");
    }

    function deployCustodian(string memory endpoint) public returns (address) {
        vm.prank(admin);
        ICustodianFactory custodianFactory = ICustodianFactory(custodianFactory);
        return custodianFactory.create(endpoint);
    }

    /// ----------------------------------------------------------------

    function test_Init_ExpirationPeriod() public view {
        // test initialized treasury address
        uint256 expected = 180 days;
        uint256 period = ICustodianExpirable(custodianReferendum).getExpirationPeriod();
        assertEq(period, expected);
    }

    function test_SetExpirationPeriod_ValidExpiration() public {
        uint256 expireIn = 3600; // seconds
        vm.prank(governor);
        ICustodianExpirable(custodianReferendum).setExpirationPeriod(expireIn);
        assertEq(ICustodianExpirable(custodianReferendum).getExpirationPeriod(), expireIn);
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
        _setFeesAsGovernor(expectedFees); // free enrollment: test purpose
        // after register a custodian a Registered event is expected
        vm.warp(1641070803);
        vm.startPrank(admin);
        // approve fees payment: admin default account
        IERC20(token).approve(ledger, expectedFees);
        ILedgerVault(ledger).deposit(admin, expectedFees, token);
        ILedgerVault(ledger).approve(address(agreementManager), expectedFees, token);

        address[] memory parties = new address[](1);
        parties[0] = custodian;

        uint256 proof = IAgreementManager(agreementManager).createAgreement(
            expectedFees,
            token,
            address(custodianReferendum),
            parties,
            ""
        );

        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Registered(custodian, expectedFees);
        ICustodianRegistrable(custodianReferendum).register(proof, custodian);
        vm.stopPrank();
    }

    function test_Register_ValidFees() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        // 1-set enrollment fees.
        _setFeesAsGovernor(expectedFees);
        // 2-deploy and register contract
        _registerCustodianWithApproval(custodian, expectedFees);
        // zero after disburse all the balance
        assertEq(IERC20(token).balanceOf(custodianReferendum), expectedFees);
    }

    function test_Register_RevertIf_InvalidAgreement() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        _setFeesAsGovernor(expectedFees);
        // expected revert if not valid allowance
        vm.expectRevert(abi.encodeWithSignature("NoFundsToLock()"));
        ICustodianRegistrable(custodianReferendum).register(0, custodian);
    }

    function test_Register_RevertIf_InvalidFlatFee() public {
        uint256 expectedFees = 100 * 1e18; // 100 MMC
        _setFeesAsGovernor(expectedFees);
        // expected revert if not valid allowance
        vm.expectRevert(abi.encodeWithSignature("NoFundsToLock()"));
        ICustodianRegistrable(custodianReferendum).register(0, custodian);
    }

    function test_Register_SetValidEnrollmentTime() public {
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
        assertEq(got, expected);
    }

    function test_Register_SetWaitingState() public {
        _setFeesAsGovernor(1 * 1e18);
        // register the custodian expecting the right status.
        _registerCustodianWithApproval(custodian, 1 * 1e18);
        assertTrue(ICustodianVerifiable(custodianReferendum).isWaiting(custodian));
    }

    function test_Register_RevertIf_InvalidCustodian() public {
        // register the custodian expecting the right status.
        vm.expectRevert(abi.encodeWithSignature("InvalidCustodianContract(address)", address(0)));
        ICustodianRegistrable(custodianReferendum).register(0, address(0));
    }

    function test_Approve_ApprovedEventEmitted() public {
        _setFeesAsGovernor(1 * 1e18);
        _registerCustodianWithApproval(custodian, 1 * 1e18);

        vm.prank(governor); // as governor.
        vm.warp(1641070802);
        // after register a custodian a Registered event is expected
        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Approved(custodian);
        ICustodianRegistrable(custodianReferendum).approve(custodian);
    }

    function test_Approve_SetActiveState() public {
        _registerAndApproveCustodian(custodian);
        assertTrue(ICustodianVerifiable(custodianReferendum).isActive(custodian));
    }

    function test_Approve_IncrementEnrollmentCount() public {
        address custodian2 = deployCustodian("test2.com");
        address custodian3 = deployCustodian("test3.com");

        _registerAndApproveCustodian(custodian);
        _registerAndApproveCustodian(custodian2); // still governor prank
        _registerAndApproveCustodian(custodian3); // still governor prank

        // valid approvals, increments the total of enrollments
        assertEq(ICustodianInspectable(custodianReferendum).getEnrollmentCount(), 3);
    }

    function test_Revoke_RevokedEventEmitted() public {
        _registerAndApproveCustodian(custodian); // still governor prank
        vm.prank(governor);
        vm.warp(1641070801);
        // after register a custodian a Registered event is expected
        vm.expectEmit(true, false, false, true, address(custodianReferendum));
        emit CustodianReferendum.Revoked(custodian);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
    }

    function test_Revoke_DecrementEnrollmentCount() public {
        _registerAndApproveCustodian(custodian); // still governor prank
        // valid approvals, increments the total of enrollments
        vm.prank(governor);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
        assertEq(ICustodianInspectable(custodianReferendum).getEnrollmentCount(), 0);
    }

    function test_Revoke_SetBlockedState() public {
        _registerAndApproveCustodian(custodian); // still governor prank
        // custodian get revoked by governance..
        vm.prank(governor);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
        assertTrue(ICustodianVerifiable(custodianReferendum).isBlocked(custodian));
    }

    function _setFeesAsGovernor(uint256 fees) internal {
        vm.startPrank(governor);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, custodianReferendum, fees, token);
        vm.stopPrank();
    }

    function _registerCustodianWithApproval(address d9r, uint256 approval) internal {
        // manager = contract deployer
        // only manager can pay enrollment..
        vm.startPrank(admin);
        // approve approval to ledger to deposit funds
        IERC20(token).approve(ledger, approval);
        ILedgerVault(ledger).deposit(admin, approval, token);
        ILedgerVault(ledger).approve(address(agreementManager), approval, token);

        address[] memory parties = new address[](1);
        parties[0] = d9r;

        uint256 proof = IAgreementManager(agreementManager).createAgreement(
            approval,
            token,
            address(custodianReferendum),
            parties,
            ""
        );
        // operate over msg.sender ledger registered funds
        ICustodianRegistrable(custodianReferendum).register(proof, d9r);
        vm.stopPrank();
    }

    function _registerCustodianWithGovernorAndApproval() internal {
        uint256 expectedFees = 100 * 1e18;
        _setFeesAsGovernor(expectedFees);
        _registerCustodianWithApproval(custodian, expectedFees);
    }

    function _registerAndApproveCustodian(address d9r) internal {
        // intially the balance = 0
        _setFeesAsGovernor(1 * 1e18);
        // register the custodian with fees = 100 MMC
        _registerCustodianWithApproval(d9r, 1 * 1e18);
        vm.prank(governor); // as governor.
        // distribuitor approved only by governor..
        ICustodianRegistrable(custodianReferendum).approve(d9r);
    }
}
