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
    function setUp() public initialize {
        deployCustodianReferendum();
        deployCustodianFactory();
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
        vm.expectRevert(abi.encodeWithSignature("UnauthorizedCustodianManager(address)", user));
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
        assertEq(got, expected);
    }

    function test_Register_SetWaitingState() public {
        _setFeesAsGovernor(1 * 1e18);
        address custodian = deployCustodian("contentrider.com");
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
        assertTrue(ICustodianVerifiable(custodianReferendum).isActive(custodian));
    }

    function test_Approve_IncrementEnrollmentCount() public {
        address custodian = deployCustodian("contentrider.com");
        address custodian2 = deployCustodian("test2.com");
        address custodian3 = deployCustodian("test3.com");

        _registerAndApproveCustodian(custodian);
        _registerAndApproveCustodian(custodian2); // still governor prank
        _registerAndApproveCustodian(custodian3); // still governor prank

        // valid approvals, increments the total of enrollments
        assertEq(ICustodianInspectable(custodianReferendum).getEnrollmentCount(), 3);
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
        assertEq(ICustodianInspectable(custodianReferendum).getEnrollmentCount(), 0);
    }

    function test_Revoke_SetBlockedState() public {
        address custodian = deployCustodian("contentrider.com");
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
        address[] memory parties = new address[](1);
        parties[0] = d9r;

        uint256 proof = _createAgreement(approval, parties);
        // operate over msg.sender ledger registered funds
        ICustodianRegistrable(custodianReferendum).register(proof, d9r);
        vm.stopPrank();
    }

    function _createAgreement(uint256 amount, address[] memory parties) private returns (uint256) {
        IERC20(token).approve(ledger, amount);
        ILedgerVault(ledger).deposit(admin, amount, token);

        uint256 proof = IAgreementManager(agreementManager).createAgreement(
            amount,
            token,
            address(custodianReferendum),
            parties,
            ""
        );

        return proof;
    }

    function _registerCustodianWithGovernorAndApproval() private {
        uint256 expectedFees = 100 * 1e18;
        address custodian = deployCustodian("contentrider.com");
        _setFeesAsGovernor(expectedFees);
        _registerCustodianWithApproval(custodian, expectedFees);
    }

    function _registerAndApproveCustodian(address d9r) private {
        // intially the balance = 0
        _setFeesAsGovernor(1 * 1e18);
        // register the custodian with fees = 100 MMC
        _registerCustodianWithApproval(d9r, 1 * 1e18);
        vm.prank(governor); // as governor.
        // distribuitor approved only by governor..
        ICustodianRegistrable(custodianReferendum).approve(d9r);
    }
}
