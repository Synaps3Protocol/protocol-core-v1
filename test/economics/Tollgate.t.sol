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

    // function test_addSupportedCurrencyLength() public {
    //     address currency = vm.addr(1); // example address
    //     address currency2 = vm.addr(2); // example address
    //     address currency3 = vm.addr(3); // example address
    //     _addCurrency(currency);
    //     _addCurrency(currency2);
    //     _addCurrency(currency3);
    //     address[] memory got = supportedCurrencies();
    //     assertEq(got.length, 3);
    // }

    // function test_removeSupportedCurrencyLength() public {
    //     address currency = vm.addr(1); // example address
    //     address currency2 = vm.addr(2); // example address
    //     address currency3 = vm.addr(3); // example address
    //     _addCurrency(currency);
    //     _addCurrency(currency2);
    //     _addCurrency(currency3);
    //     _removeCurrency(currency2);

    //     address[] memory got = supportedCurrencies();
    //     assertEq(got.length, 2);
    // }

    // function test_supportedCurrencies() public {
    //     address currency = vm.addr(1); // example address
    //     address currency2 = vm.addr(2); // example address
    //     _addCurrency(currency);
    //     _addCurrency(currency2);

    //     address[] memory got = supportedCurrencies();
    //     address[] memory expected = new address[](2);
    //     expected[0] = currency;
    //     expected[1] = currency2;
    //     assertEq(got, expected);
    // }

    // function test_skipAddExisting() public {
    //     address currency = vm.addr(1); // example address
    //     _addCurrency(currency);
    //     _addCurrency(currency);
    //     // added two time the same currency it's skipped
    //     address[] memory got = supportedCurrencies();
    //     assertEq(got.length, 1);
    // }

    // function testFail_RevertWhen_removeNotExisting() public {
    //     vm.expectRevert(InvalidCurrency.selector);
    //     address currency = vm.addr(1); // example address
    //     _removeCurrency(currency);
    // }

    // function test_Create_ValidDistributor() public {
    //     address distributor = deployDistributor("test.com");
    //     assertEq(IERC165(distributor).supportsInterface(type(IDistributor).interfaceId), true);
    //     assertEq(IDistributor(distributor).getEndpoint(), "test.com");
    // }
}
