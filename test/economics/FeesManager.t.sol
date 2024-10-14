pragma solidity 0.8.26;

import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/libraries/Types.sol";

contract TollgateTest is BaseTest {

    address manager;
    address token;

    function setUp() public {
        token = deployToken();
        manager = deployTollgate();
    }

    function test_SetFees_ValidSyndicationFees() public {
        uint256 expected = 1e18;
        ITollgate(manager).setFees(T.Context.SYN, expected, token);
        assertEq(ITollgate(manager).getFees(T.Context.SYN, token), expected);
    }

    // function test_SetFeesNative() public {
    //     uint256 expected = 1e18;
    //     _setFees(expected, address(0));
    //     assertEq(getFees(address(0)), expected);
    // }

    // function test_RevertWhen_NotSupportedCurrency() public {
    //     vm.expectRevert(abi.encodeWithSignature("InvalidUnsupportedCurrency(address)", address(0)));
    //     getFees(address(0));
    // }

    // function test_addCurrency() public {
    //     address currency = vm.addr(1); // example address
    //     _addCurrency(currency);
    //     assertEq(isCurrencySupported(currency), true);
    // }

    // function test_removeCurrency() public {
    //     address currency = vm.addr(1); // example address
    //     _addCurrency(currency);
    //     _removeCurrency(currency);
    //     assertEq(isCurrencySupported(currency), false);
    // }

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
