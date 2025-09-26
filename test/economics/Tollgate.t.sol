// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { Tollgate } from "contracts/economics/Tollgate.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { T } from "contracts/core/primitives/Types.sol";

contract TargetA {}

contract TargetB {}

contract TargetC {}

contract TargetD {
    /// @notice Checks if the given fee scheme is supported in this context.
    /// @param scheme The fee scheme to validate.
    /// @return True if the scheme is supported.
    function isFeeSchemeSupported(T.Scheme scheme) external pure returns (bool) {
        // support only FLAT scheme
        return scheme == T.Scheme.FLAT;
    }
}

contract TollgateHandler is Test {
    struct FeeState {
        bool exists;
        uint256 fee;
    }

    address public immutable tollgate;
    address public immutable governor;
    address[] public targets;
    address[] public currencies;

    mapping(address => T.Scheme) private _schemes;
    mapping(address => mapping(address => FeeState)) private _fees;
    mapping(address => address[]) private _targetCurrencies;
    mapping(address => mapping(address => bool)) private _currencyTracked;

    constructor(address tollgate_, address governor_, address token_) {
        tollgate = tollgate_;
        governor = governor_;

        targets.push(address(new TargetA()));
        targets.push(address(new TargetB()));
        targets.push(address(new TargetC()));
        targets.push(address(new TargetD()));

        _schemes[targets[0]] = T.Scheme.FLAT;
        _schemes[targets[1]] = T.Scheme.NOMINAL;
        _schemes[targets[2]] = T.Scheme.BPS;
        _schemes[targets[3]] = T.Scheme.FLAT;

        currencies.push(token_);
        currencies.push(vm.addr(910));
        currencies.push(vm.addr(911));
    }

    function setFees(uint256 targetSeed, uint256 currencySeed, uint256 feeSeed) external {
        if (targets.length == 0) return;
        address target = targets[targetSeed % targets.length];
        address currency = currencies[currencySeed % currencies.length];
        T.Scheme scheme = _schemes[target];

        uint256 fee;
        if (scheme == T.Scheme.FLAT) {
            fee = bound(feeSeed, 1, type(uint96).max);
        } else if (scheme == T.Scheme.NOMINAL) {
            fee = bound(feeSeed, 1, 100);
        } else {
            fee = bound(feeSeed, 1, 10_000);
        }

        vm.prank(governor);
        ITollgate(tollgate).setFees(scheme, target, fee, currency);

        FeeState storage state = _fees[target][currency];
        state.exists = true;
        state.fee = fee;

        if (!_currencyTracked[target][currency]) {
            _currencyTracked[target][currency] = true;
            _targetCurrencies[target].push(currency);
        }
    }

    function targetsLength() external view returns (uint256) {
        return targets.length;
    }

    function targetAt(uint256 index) external view returns (address) {
        return targets[index];
    }

    function schemeOf(address target) external view returns (T.Scheme) {
        return _schemes[target];
    }

    function currenciesFor(address target) external view returns (address[] memory) {
        return _targetCurrencies[target];
    }

    function feeState(address target, address currency) external view returns (FeeState memory) {
        return _fees[target][currency];
    }
}

contract TollgateTest is BaseTest {
    function setUp() public initialize {
        deployTollgate();
        deployCustodianReferendum();
    }

    function test_SetFees_ValidFlatFees() public {
        uint256 expected = 1e18; // expected flat fees
        address target = address(new TargetA());
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, expected, token);

        (uint256 fee, T.Scheme scheme) = ITollgate(tollgate).getFees(target, token);
        assertEq(uint256(scheme), 1, "Expected scheme should be FLAT");
        assertEq(fee, expected, "Expected fee should match");
    }

    function test_SetFees_ValidBasePointAgreementFees() public {
        uint256 expected = 5 * 100; // 500 bps = 5% nominal expected base point
        address target = address(new TargetA());
        vm.prank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.BPS, target, expected, token);

        (uint256 fee, T.Scheme scheme) = ITollgate(tollgate).getFees(target, token);
        assertEq(uint256(scheme), 3, "Expected scheme should be BPS");
        assertEq(fee, expected, "Expected fee should match");
    }

    function test_SetFees_FeesSetEventEmitted() public {
        uint256 expected = 1e18; // expected flat fees
        address target = address(new TargetA());
        vm.prank(governor); // as governor set fees
        vm.expectEmit(true, true, false, true, address(tollgate));
        emit Tollgate.FeesSet(target, token, T.Scheme.FLAT, expected);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, expected, token);
    }

    function test_SetFees_RevertWhen_InvalidBasePointFees() public {
        uint256 invalidFees = 10_001; // overflowed base points max = 10_000
        address target = address(new TargetA());
        vm.prank(governor); // as governor set fees
        vm.expectRevert(abi.encodeWithSignature("InvalidBasisPointRange(uint256)", invalidFees));
        ITollgate(tollgate).setFees(T.Scheme.BPS, target, invalidFees, token);
    }

    function test_SetFees_RevertWhen_InvalidNominalFees() public {
        uint256 invalidFees = 101; // overflowed base points max = 10_000
        address target = address(new TargetA());
        vm.prank(governor); // as governor set fees
        vm.expectRevert(abi.encodeWithSignature("InvalidNominalRange(uint256)", invalidFees));
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, target, invalidFees, token);
    }

    function test_SetFees_RevertIf_NotSupportedSchemeByTarget() public {
        vm.startPrank(governor);
        // expected revert if not valid allowance
        address notSupportedNominal = address(new TargetD());
        vm.expectRevert(abi.encodeWithSignature("InvalidTargetScheme(address)", notSupportedNominal));
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, notSupportedNominal, 1, token);
        vm.stopPrank();
    }

    function test_GetFees_ValidExpectedFees() public {
        uint256 expectedFlat = 1e18; // 1MMC expected flat fees
        uint256 expectedBps = 10 * 100; // = 10% expected bps
        uint256 expectedNominal = 50; // = 50% expected bps
        address targetA = address(new TargetA());
        address targetB = address(new TargetB());
        address targetC = address(new TargetC());

        vm.startPrank(governor); // as governor set fees
        ITollgate(tollgate).setFees(T.Scheme.FLAT, targetA, expectedFlat, token);
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, targetB, expectedNominal, token);
        ITollgate(tollgate).setFees(T.Scheme.BPS, targetC, expectedBps, token);
        vm.stopPrank();

        (uint256 feeA, T.Scheme a) = ITollgate(tollgate).getFees(targetA, token);
        (uint256 feeB, T.Scheme b) = ITollgate(tollgate).getFees(targetB, token);
        (uint256 feeC, T.Scheme c) = ITollgate(tollgate).getFees(targetC, token);

        assertEq(feeA, expectedFlat, "Expected flat fee should match");
        assertEq(uint256(a), 1, "Expected scheme should be FLAT");
        assertEq(feeB, expectedNominal, "Expected nominal fee should match");
        assertEq(uint256(b), 2, "Expected scheme should be NOMINAL");
        assertEq(feeC, expectedBps, "Expected bps fee should match");
        assertEq(uint256(c), 3, "Expected scheme should be BPS");
    }

    function test_GetFees_RevertWhen_NotSupportedScheme() public {
        address invalidTokenAddress = vm.addr(3);
        address target = vm.addr(8);
        vm.expectRevert(abi.encodeWithSignature("UnsupportedCurrency(address,address)", target, invalidTokenAddress));
        ITollgate(tollgate).getFees(target, invalidTokenAddress);
    }

    function test_SupportedCurrencies_ReturnExpectedCurrencies() public {
        address target = custodianReferendum;
        vm.startPrank(governor); // as governor set fees
        // duplicate the registration to check if the token is duplicated
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, 1, token);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, 1, token);
        vm.stopPrank();

        address[] memory got = ITollgate(tollgate).supportedCurrencies(target);
        address[] memory expected = new address[](1);
        expected[0] = token;

        // only one expected since the set avoid dupes..
        assertEq(got, expected, "Expected supported currencies should match");
    }

    function testFuzz_SetFees_Flat(uint256 fee, address currency) public {
        vm.assume(currency != address(0));
        address target = address(new TargetA());
        fee = bound(fee, 1, type(uint96).max);

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, fee, currency);

        (uint256 stored, T.Scheme scheme) = ITollgate(tollgate).getFees(target, currency);
        assertEq(stored, fee, "Flat fee should match");
        assertEq(uint256(scheme), uint256(T.Scheme.FLAT), "Scheme should be FLAT");
    }

    function testFuzz_SetFees_Nominal(uint256 fee, address currency) public {
        vm.assume(currency != address(0));
        address target = address(new TargetB());
        fee = bound(fee, 1, 100);

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, target, fee, currency);

        (uint256 stored, T.Scheme scheme) = ITollgate(tollgate).getFees(target, currency);
        assertEq(stored, fee, "Nominal fee should match");
        assertEq(uint256(scheme), uint256(T.Scheme.NOMINAL), "Scheme should be NOMINAL");
    }

    function testFuzz_SetFees_Bps(uint256 fee, address currency) public {
        vm.assume(currency != address(0));
        address target = address(new TargetC());
        fee = bound(fee, 1, 10_000);

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, target, fee, currency);

        (uint256 stored, T.Scheme scheme) = ITollgate(tollgate).getFees(target, currency);
        assertEq(stored, fee, "BPS fee should match");
        assertEq(uint256(scheme), uint256(T.Scheme.BPS), "Scheme should be BPS");
    }

    function testFuzz_SupportedCurrencies_NoDuplicates(
        uint256 feeA,
        uint256 feeB,
        address currency
    ) public {
        vm.assume(currency != address(0));
        address target = address(new TargetA());
        feeA = bound(feeA, 1, type(uint96).max);
        feeB = bound(feeB, 1, type(uint96).max);

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, feeA, currency);

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, target, feeB, currency);

        address[] memory supported = ITollgate(tollgate).supportedCurrencies(target);
        assertEq(supported.length, 1, "Supported currencies should not duplicate entries");
        assertEq(supported[0], currency, "Supported currency should match input");
    }
}

contract TollgateInvariantTest is BaseTest {
    TollgateHandler handler;

    function setUp() public initialize {
        deployTollgate();

        handler = new TollgateHandler(tollgate, governor, token);
        targetContract(address(handler));
    }

    function invariant_FeesMatchHandlerState() external view {
        ITollgate tollgateContract = ITollgate(tollgate);
        uint256 len = handler.targetsLength();

        for (uint256 i = 0; i < len; i++) {
            address target = handler.targetAt(i);
            address[] memory currenciesList = handler.currenciesFor(target);
            T.Scheme scheme = handler.schemeOf(target);

            for (uint256 j = 0; j < currenciesList.length; j++) {
                address currency = currenciesList[j];
                TollgateHandler.FeeState memory state = handler.feeState(target, currency);
                if (!state.exists) continue;

                (uint256 fee, T.Scheme storedScheme) = tollgateContract.getFees(target, currency);
                assertEq(fee, state.fee, "Fee must align with handler state");
                assertEq(uint256(storedScheme), uint256(scheme), "Scheme must align with handler state");
            }
        }
    }

    function invariant_SupportedCurrenciesAligned() external view {
        ITollgate tollgateContract = ITollgate(tollgate);
        uint256 len = handler.targetsLength();

        for (uint256 i = 0; i < len; i++) {
            address target = handler.targetAt(i);
            address[] memory handlerCurrencies = handler.currenciesFor(target);
            address[] memory supported = tollgateContract.supportedCurrencies(target);

            uint256 expectedCount = 0;
            for (uint256 j = 0; j < handlerCurrencies.length; j++) {
                TollgateHandler.FeeState memory state = handler.feeState(target, handlerCurrencies[j]);
                if (state.exists) expectedCount++;
            }

            assertEq(supported.length, expectedCount, "Supported currency count mismatch");

            for (uint256 j = 0; j < handlerCurrencies.length; j++) {
                address currency = handlerCurrencies[j];
                TollgateHandler.FeeState memory state = handler.feeState(target, currency);
                if (!state.exists) continue;

                bool found = false;
                for (uint256 k = 0; k < supported.length; k++) {
                    if (supported[k] == currency) {
                        found = true;
                        break;
                    }
                }
                assertTrue(found, "Supported currency missing from Tollgate state");
            }
        }
    }
}
