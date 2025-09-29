// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { FeesOps } from "contracts/core/libraries/FeesOps.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract FeesOpsHarness {
    function isBasePoint(uint256 fee) external pure returns (bool) {
        return FeesOps.isBasePoint(fee);
    }

    function isNominal(uint256 fee) external pure returns (bool) {
        return FeesOps.isNominal(fee);
    }

    function perOf(uint256 amount, uint256 bps) external pure returns (uint256) {
        return FeesOps.perOf(amount, bps);
    }

    function calcBps(uint256 percentage) external pure returns (uint256) {
        return FeesOps.calcBps(percentage);
    }
}

contract FeesOpsTest is Test {
    FeesOpsHarness harness;

    function setUp() public {
        harness = new FeesOpsHarness();
    }

    function test_IsBasePoint_TrueWhenWithinBpsMax() public {
        assertTrue(harness.isBasePoint(C.BPS_MAX), "BPS max should be valid");
        assertTrue(harness.isBasePoint(0), "Zero should be valid bps");
    }

    function test_IsBasePoint_FalseWhenAboveMax() public {
        assertFalse(harness.isBasePoint(C.BPS_MAX + 1), "Above max should be invalid");
    }

    function test_IsNominal_TrueWhenWithinScale() public {
        assertTrue(harness.isNominal(C.SCALE_FACTOR), "Scale factor should be valid nominal");
        assertTrue(harness.isNominal(0), "Zero should be valid nominal");
    }

    function test_IsNominal_FalseWhenAboveScale() public {
        assertFalse(harness.isNominal(C.SCALE_FACTOR + 1), "Above scale should be invalid nominal");
    }

    function test_PerOf_ComputesPercentage() public {
        uint256 amount = 1_000 ether;
        uint256 bps = 250; // 2.5%
        uint256 expected = (amount * bps) / C.BPS_MAX;
        assertEq(harness.perOf(amount, bps), expected, "Percentage calculation mismatch");
    }

    function test_PerOf_RevertsWhen_BpsAboveMax() public {
        vm.expectRevert(bytes("BPS cannot be greater than 10_000"));
        harness.perOf(1, C.BPS_MAX + 1);
    }

    function test_CalcBps_ComputesNominalToBps() public {
        uint256 per = 5;
        assertEq(harness.calcBps(per), per * C.SCALE_FACTOR, "calcBps mismatch");
    }

    function testFuzz_PerOfMatchesManual(uint256 amount, uint256 bps) public {
        amount = bound(amount, 0, type(uint128).max);
        bps = bound(bps, 0, C.BPS_MAX);

        uint256 expected = (amount * bps) / C.BPS_MAX;
        assertEq(harness.perOf(amount, bps), expected, "Fuzz percentage mismatch");
    }

    function testFuzz_CalcBpsInverse(uint256 per) public {
        per = bound(per, 0, 1_000_000);
        uint256 bps = harness.calcBps(per);
        assertEq(bps / C.SCALE_FACTOR, per, "calcBps inverse mismatch");
    }
}

contract FeesOpsHandler is Test {
    FeesOpsHarness public immutable harness;

    uint256 internal _totalAmount;
    uint256 internal _lastCalcBps;

    constructor(FeesOpsHarness harness_) {
        harness = harness_;
    }

    function recordPerOf(uint256 amount, uint256 bps) external {
        bps = bound(bps, 0, C.BPS_MAX);
        amount = bound(amount, 0, type(uint128).max);
        uint256 result = harness.perOf(amount, bps);
        _totalAmount += result;
    }

    function recordCalcBps(uint256 per) external {
        per = bound(per, 0, 1_000_000);
        _lastCalcBps = harness.calcBps(per);
    }

    function reset() external {
        _totalAmount = 0;
        _lastCalcBps = 0;
    }

    function totalAmount() external view returns (uint256) {
        return _totalAmount;
    }

    function lastCalcBps() external view returns (uint256) {
        return _lastCalcBps;
    }
}

contract FeesOpsInvariantTest is Test {
    FeesOpsHarness harness;
    FeesOpsHandler handler;

    function setUp() public {
        harness = new FeesOpsHarness();
        handler = new FeesOpsHandler(harness);
        targetContract(address(handler));
    }

    function invariant_TotalAmountWithinBounds() external view {
        assertLe(handler.totalAmount(), type(uint256).max, "Total amount overflowed");
    }

    function invariant_LastPercentageValid() external view {
        assertEq(handler.lastCalcBps() % C.SCALE_FACTOR, 0, "calcBps outputs should be multiples of scale factor");
    }
}
