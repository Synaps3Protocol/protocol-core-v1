// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseTest } from "test/BaseTest.t.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { T } from "contracts/core/primitives/Types.sol";

contract TollgateTest is BaseTest {
    address tollgate;
    address token;

    function setUp() public initialize {
        // setup the access manager to use during tests..
        token = deployToken();
        tollgate = deployTollgate();
    }

    function test_SetFees_ValidFlatSyndicationFees() public {
        uint256 expected = 1e18; // expected flat fees
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, expected, token);
        assertEq(ITollgate(tollgate).getFees(T.Scheme.FLAT, target, token), expected);
    }

    function test_SetFees_ValidBasePointAgreementFees() public {
        uint256 expected = 5 * 100; // 500 bps = 5% nominal expected base point
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.BPS, target, expected, token);
        assertEq(ITollgate(tollgate).getFees(T.Scheme.BPS, target, token), expected);
    }

    function test_SetFees_FeesSetEventEmitted() public {
        uint256 expected = 1e18; // expected flat fees
        address target = vm.addr(8);
        vm.prank(governor); // as governor set fees
        vm.expectEmit(true, true, false, true, address(tollgate));
        emit Tollgate.FeesSet(target, token, governor, T.Scheme.FLAT, expected);
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
        address target = vm.addr(8);

        vm.startPrank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, expectedFlat, token);
        ITollgate(tollgate).setFees(T.Scheme.BPS, target, expectedBps, token);
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, target, expectedNominal, token);
        vm.stopPrank();

        assertEq(ITollgate(tollgate).getFees(T.Scheme.FLAT, target, token), expectedFlat);
        assertEq(ITollgate(tollgate).getFees(T.Scheme.BPS, target, token), expectedBps);
        assertEq(ITollgate(tollgate).getFees(T.Scheme.NOMINAL, target, token), expectedNominal);
    }

    function test_GetFees_RevertWhen_NotSupportedCurrency() public {
        address invalidTokenAddress = vm.addr(3);
        address target = vm.addr(8);
        vm.expectRevert(abi.encodeWithSignature("InvalidUnsupportedCurrency(address)", invalidTokenAddress));
        ITollgate(tollgate).getFees(T.Scheme.FLAT, target, invalidTokenAddress);
    }

    function test_SupportedCurrencies_ReturnExpectedCurrencies() public {
        address target = vm.addr(8);
        vm.startPrank(governor); // as governor set fees
        // duplicate the registration to check if the token is duplicated
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, 1, token);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, 1, token);
        vm.stopPrank();

        vm.prank(user); // user querying fees..
        address[] memory got = ITollgate(tollgate).supportedCurrencies(target);
        address[] memory expected = new address[](1);
        expected[0] = token;

        // only one expected since the set avoid dupes..
        assertEq(got, expected);
    }

    function test_IsSchemeSupported_ReturnExpectedTrueOrFalse() public {
        vm.prank(governor); // as governor set fees
        address target = vm.addr(8);
        // duplicate the registration to check if the token is duplicated
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, 1, token);
        // only one expected since the set avoid dupes..
        assertEq(ITollgate(tollgate).isSchemeSupported(T.Scheme.FLAT, target, token), true);
        assertEq(ITollgate(tollgate).isSchemeSupported(T.Scheme.NOMINAL, target, token), false);
    }
}
