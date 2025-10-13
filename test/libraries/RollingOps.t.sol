// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { RollingOps } from "contracts/core/libraries/RollingOps.sol";

contract RollingOpsHarness {
    using RollingOps for RollingOps.AddressArray;

    RollingOps.AddressArray internal set;

    function configure(uint256 window) external {
        set.configure(window);
    }

    function roll(address value) external {
        set.roll(value);
    }

    function contains(address value) external view returns (bool) {
        return set.contains(value);
    }

    function length() external view returns (uint256) {
        return set.length();
    }

    function window() external view returns (uint256) {
        return set.window();
    }

    function at(uint256 index) external view returns (address) {
        return set.at(index);
    }

    function values() external view returns (address[] memory) {
        return set.values();
    }
}

contract RollingOpsTest is Test {
    RollingOpsHarness harness;

    function setUp() public {
        harness = new RollingOpsHarness();
    }

    function test_DefaultWindow_IsThree() public {
        assertEq(harness.window(), 3, "Default window mismatch");
        assertEq(harness.length(), 0, "Initial length should be zero");
    }

    function test_Configure_SetsCustomWindow() public {
        harness.configure(5);
        assertEq(harness.window(), 5, "Window should update to configured value");
    }

    function test_Configure_RevertWhen_ZeroWindow() public {
        vm.expectRevert(RollingOps.InvalidZeroWindowSize.selector);
        harness.configure(0);
    }

    function test_Roll_AppendsUntilWindow() public {
        address a = vm.addr(1);
        address b = vm.addr(2);
        harness.roll(a);
        harness.roll(b);
        assertEq(harness.length(), 2, "Length mismatch after roll");
        assertEq(harness.at(0), a, "First element mismatch");
        assertEq(harness.at(1), b, "Second element mismatch");
    }

    function test_Roll_RollsOutOldestWhenWindowExceeded() public {
        harness.configure(3);
        address[4] memory addrs = [vm.addr(1), vm.addr(2), vm.addr(3), vm.addr(4)];
        for (uint256 i = 0; i < addrs.length; i++) {
            harness.roll(addrs[i]);
        }

        assertEq(harness.length(), 3, "Length should not exceed window");
        assertEq(harness.at(0), addrs[1], "Oldest element not rolled out");
        assertEq(harness.at(1), addrs[2], "Order mismatch after roll");
        assertEq(harness.at(2), addrs[3], "Newest element missing");
    }

    function test_Contains_ReturnsFalseWhenMissing() public {
        assertFalse(harness.contains(vm.addr(99)), "Contains should be false for missing value");
    }

    function test_Contains_ReturnsTrueAfterRoll() public {
        address value = vm.addr(42);
        harness.roll(value);
        assertTrue(harness.contains(value), "Contains should be true after roll");
    }

    function test_At_RevertWhen_IndexOutOfBounds() public {
        vm.expectRevert(RollingOps.IndexOutOfBounds.selector);
        harness.at(0);
    }

    function test_Values_ReturnsAllInOrder() public {
        harness.configure(3);
        address[3] memory addrs = [vm.addr(1), vm.addr(2), vm.addr(3)];
        for (uint256 i = 0; i < addrs.length; i++) {
            harness.roll(addrs[i]);
        }

        address[] memory vals = harness.values();
        assertEq(vals.length, 3, "Values length mismatch");
        for (uint256 i = 0; i < vals.length; i++) {
            assertEq(vals[i], addrs[i], "Values order mismatch");
        }
    }

    function test_Integration_ConfiguredWindowFlow() public {
        harness.configure(2);
        address a = vm.addr(1);
        address b = vm.addr(2);
        address c = vm.addr(3);

        harness.roll(a);
        harness.roll(b);
        harness.roll(c);

        assertEq(harness.length(), 2, "Length should clamp to window size");
        assertEq(harness.at(0), b, "First element should be second rolled");
        assertEq(harness.at(1), c, "Second element should be latest rolled");
        assertFalse(harness.contains(a), "Rolled out element should not be contained");
    }
}
