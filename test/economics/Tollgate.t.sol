// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { BaseTest } from "test/BaseTest.t.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { T } from "contracts/core/primitives/Types.sol";

contract TollgateTest is BaseTest {

    function setUp() public initialize {
        deployTollgate();
    }

    function test_SetFees_ValidFlatFees() public {
        uint256 expected = 1e18; // expected flat fees
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, expected, token);

        (uint256 fee, T.Scheme scheme) = ITollgate(tollgate).getFees(target, token);
        assertEq(uint256(scheme), 1);
        assertEq(fee, expected);
    }

    function test_SetFees_ValidBasePointAgreementFees() public {
        uint256 expected = 5 * 100; // 500 bps = 5% nominal expected base point
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.BPS, target, expected, token);

        (uint256 fee, T.Scheme scheme) = ITollgate(tollgate).getFees(target, token);
        assertEq(uint256(scheme), 3);
        assertEq(fee, expected);
    }

    function test_SetFees_FeesSetEventEmitted() public {
        uint256 expected = 1e18; // expected flat fees
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        vm.expectEmit(true, true, false, true, address(tollgate));
        emit Tollgate.FeesSet(target, token, T.Scheme.FLAT, expected);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, expected, token);
    }

    function test_SetFees_RevertWhen_InvalidBasePointFees() public {
        uint256 invalidFees = 10_001; // overflowed base points max = 10_000
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        vm.expectRevert(abi.encodeWithSignature("InvalidBasisPointRange(uint256)", invalidFees));
        ITollgate(tollgate).setFees(T.Scheme.BPS, target, invalidFees, token);
    }

    function test_SetFees_RevertWhen_InvalidNominalFees() public {
        uint256 invalidFees = 101; // overflowed base points max = 10_000
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        vm.expectRevert(abi.encodeWithSignature("InvalidNominalRange(uint256)", invalidFees));
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, target, invalidFees, token);
    }

    function test_GetFees_ValidExpectedFees() public {
        uint256 expectedFlat = 1e18; // 1MMC expected flat fees
        uint256 expectedBps = 10 * 100; // = 10% expected bps
        uint256 expectedNominal = 50; // = 50% expected bps
        address targetA = vm.addr(8);
        address targetB = vm.addr(9);
        address targetC = vm.addr(10);

        vm.startPrank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.FLAT, targetA, expectedFlat, token);
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, targetB, expectedNominal, token);
        ITollgate(tollgate).setFees(T.Scheme.BPS, targetC, expectedBps, token);
        vm.stopPrank();

        (uint256 feeA, T.Scheme a) = ITollgate(tollgate).getFees(targetA, token);
        (uint256 feeB, T.Scheme b) = ITollgate(tollgate).getFees(targetB, token);
        (uint256 feeC, T.Scheme c) = ITollgate(tollgate).getFees(targetC, token);

        assertEq(feeA, expectedFlat);
        assertEq(uint256(a), 1);
        assertEq(feeB, expectedNominal);
        assertEq(uint256(b), 2);
        assertEq(feeC, expectedBps);
        assertEq(uint256(c), 3);
    }

    // function test_GetFees_RevertWhen_NotSupportedCurrency() public {
    //     address invalidTokenAddress = vm.addr(3);
    //     address target = vm.addr(8);
    //     vm.expectRevert(abi.encodeWithSignature("InvalidUnsupportedCurrency(address)", invalidTokenAddress));
    //     ITollgate(tollgate).getFees(T.Scheme.FLAT, target, invalidTokenAddress);
    // }

    // function test_SupportedCurrencies_ReturnExpectedCurrencies() public {
    //     address target = vm.addr(8);
    //     vm.startPrank(governor); // as governor set fees
    //     // duplicate the registration to check if the token is duplicated
    //     ITollgate(tollgate).setFees(T.Scheme.FLAT, target, 1, token);
    //     ITollgate(tollgate).setFees(T.Scheme.FLAT, target, 1, token);
    //     vm.stopPrank();

    //     vm.prank(user); // user querying fees..
    //     address[] memory got = ITollgate(tollgate).supportedCurrencies(target);
    //     address[] memory expected = new address[](1);
    //     expected[0] = token;

    //     // only one expected since the set avoid dupes..
    //     assertEq(got, expected);
    // }
}
