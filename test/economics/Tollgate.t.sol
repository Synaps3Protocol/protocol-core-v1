pragma solidity 0.8.26;

import { Tollgate } from "contracts/economics/Tollgate.sol";
import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/libraries/Types.sol";

contract TollgateTest is BaseTest {
    address tollgate;
    address token;

    function setUp() public {
        token = deployToken();
        tollgate = deployTollgate();
        setGovernorTo(tollgate);
    }

    function test_SetFees_ValidFlatSyndicationFees() public {
        uint256 expected = 1e18; // expected flat fees
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Context.SYN, expected, token);
        vm.prank(user); // user querying fees..
        assertEq(ITollgate(tollgate).getFees(T.Context.SYN, token), expected);
    }

    function test_SetFees_ValidBasePointAgreementFees() public {
        uint256 expected = 5 * 100; // 500 bps = 5% nominal expected base point
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Context.RMA, expected, token);
        vm.prank(user); // user querying fees..
        assertEq(ITollgate(tollgate).getFees(T.Context.RMA, token), expected);
    }

        function test_SetFees_FeesSetEventEmmited() public {
        uint256 expected = 1e18; // expected flat fees
        vm.prank(governor); // as governor set fees
        vm.expectEmit(true, true, false, true, address(tollgate));
        emit Tollgate.FeesSet(expected, T.Context.SYN, token, governor);
        ITollgate(tollgate).setFees(T.Context.SYN, expected, token);
    }

    function test_SetFees_RevertWhen_InvalidBasePointAgreementFees() public {
        uint256 invalidFees = 10_001; // overflowed base points max = 10_000
        vm.prank(governor); // as governor set fees
        vm.expectRevert(abi.encodeWithSignature("InvalidBasisPointRange(uint256)", invalidFees));
        ITollgate(tollgate).setFees(T.Context.RMA, invalidFees, token);
    }

    function test_SetFees_RevertWhen_InvalidCurrency() public {
        address invalidTokenAddress = vm.addr(3);
        vm.prank(governor); // as governor set fees
        vm.expectRevert(abi.encodeWithSignature("InvalidCurrency(address)", invalidTokenAddress));
        ITollgate(tollgate).setFees(T.Context.SYN, 1, invalidTokenAddress);
    }

    function test_GetFees_ValidExpectedFees() public {
        uint256 expectedSyndication = 1e18; // 1MMC expected flat fees
        uint256 expectedRightsAgreement = 10 * 100; // = 10% expected bps

        vm.startPrank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Context.SYN, expectedSyndication, token);
        ITollgate(tollgate).setFees(T.Context.RMA, expectedRightsAgreement, token);
        vm.stopPrank();

        vm.prank(user); // user querying fees..
        assertEq(ITollgate(tollgate).getFees(T.Context.SYN, token), expectedSyndication);
        assertEq(ITollgate(tollgate).getFees(T.Context.RMA, token), expectedRightsAgreement);
    }

    function test_GetFees_RevertWhen_NotSupportedCurrency() public {
        address invalidTokenAddress = vm.addr(3);
        vm.expectRevert(abi.encodeWithSignature("InvalidUnsupportedCurrency(address)", invalidTokenAddress));
        ITollgate(tollgate).getFees(T.Context.SYN, invalidTokenAddress);
    }

    function test_SupportedCurrencies_ReturnExpectedCurrencies() public {
        vm.startPrank(governor); // as governor set fees
        // duplicate the registration to check if the token is duplicated
        ITollgate(tollgate).setFees(T.Context.SYN, 1, token);
        ITollgate(tollgate).setFees(T.Context.SYN, 1, token);
        vm.stopPrank();

        vm.prank(user); // user querying fees..
        address[] memory got = ITollgate(tollgate).supportedCurrencies(T.Context.SYN);
        address[] memory expected = new address[](1);
        expected[0] = token;

        // only one expected since the set avoid dupes..
        assertEq(got, expected);
    }

    function test_IsCurrencySupported_ReturnExpectedTrueOrFalse() public {
        vm.prank(governor); // as governor set fees
        // duplicate the registration to check if the token is duplicated
        ITollgate(tollgate).setFees(T.Context.SYN, 1, token);
        // only one expected since the set avoid dupes..
        assertEq(ITollgate(tollgate).isCurrencySupported(T.Context.SYN, token), true);
        assertEq(ITollgate(tollgate).isCurrencySupported(T.Context.RMA, token), false);
    }
}
