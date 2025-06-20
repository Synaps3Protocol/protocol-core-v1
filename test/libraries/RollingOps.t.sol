// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { RollingOps } from "contracts/core/libraries/RollingOps.sol";
import { console } from "forge-std/console.sol";

/// @title RollingOpsWrapper
/// @notice A wrapper contract to test the RollingOps library using Foundry.
contract RollingOpsWrapper {
    using RollingOps for RollingOps.AddressArray;

    RollingOps.AddressArray private rollingArray;

    /// @notice Configures the max window size of the rolling array.
    /// @param window The new max size of the array.
    function configureWindow(uint256 window) external {
        rollingArray.configure(window);
    }

    /// @notice Returns the maximum window size.
    function getWindow() external view returns (uint256) {
        return rollingArray.window();
    }

    /// @notice Adds a new address to the rolling array.
    /// @param value The address to be added.
    function add(address value) external {
        rollingArray.roll(value);
    }

    /// @notice Checks if an address exists in the rolling array.
    /// @param value The address to check.
    /// @return exists True if the address is in the rolling array, false otherwise.
    function exists(address value) external view returns (bool) {
        return rollingArray.contains(value);
    }

    /// @notice Gets the length of the rolling array.
    /// @return The number of stored addresses.
    function getLength() external view returns (uint256) {
        return rollingArray.length();
    }

    /// @notice Gets an address at a specific index.
    /// @param index The index (1-based) to retrieve.
    /// @return The address stored at the given index.
    function getAt(uint256 index) external view returns (address) {
        return rollingArray.at(index);
    }

    /// @notice Retrieves all addresses currently stored in the rolling array.
    /// @return An array of all addresses in the rolling array.
    function getAll() external view returns (address[] memory) {
        return rollingArray.values();
    }
}

contract RollingOpsTest is Test {
    RollingOpsWrapper private rolling;

    function setUp() public {
        rolling = new RollingOpsWrapper();
    }

    function test_Window_ReturnDefaultWindowSize() public view {
        assertEq(rolling.getWindow(), 3, "Default window size should be 3");
    }

    function test_Configure_SetValidWindowSize() public {
        rolling.configureWindow(5);
        assertEq(rolling.getWindow(), 5, "Expected window size should be 5");
    }

    function test_Configure_MaximumWindowSize() public {
        uint256 maxWindow = type(uint256).max;
        rolling.configureWindow(maxWindow);
        assertEq(rolling.getWindow(), maxWindow, "Expected window size should be max uint256");
    }

    function test_RevertIf_SetZeroWindowSize() public {
        vm.expectRevert();
        rolling.configureWindow(0);
    }

    function test_Add_NotRollingElements() public {
        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);
        address addr3 = vm.addr(3);
        // using default window
        rolling.add(addr1);
        rolling.add(addr2);
        rolling.add(addr3);

        address[] memory got = rolling.getAll();
        address[] memory expected = new address[](3);
        expected[0] = addr1;
        expected[1] = addr2;
        expected[2] = addr3;

        assertEq(got, expected, "Expected addresses should match");
    }

    function test_Add_RollingOldestElement() public {
        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);
        address addr3 = vm.addr(3);
        address addr4 = vm.addr(4);

        // using default window
        rolling.add(addr1);
        rolling.add(addr2);
        rolling.add(addr3);

        // before = [addr1, addr2, addr3]
        // after = [ addr2, addr3, addr4]
        rolling.add(addr4);

        address[] memory got = rolling.getAll();
        address[] memory expected = new address[](3);
        expected[0] = addr2;
        expected[1] = addr3;
        expected[2] = addr4;

        assertEq(got, expected, "Expected addresses should match after rolling");
    }

    function test_Add_SizeOne() public {
        rolling.configureWindow(1);
        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);

        rolling.add(addr1);
        assertEq(rolling.getAt(0), addr1, "First address should be addr1");

        rolling.add(addr2);
        assertEq(rolling.getAt(0), addr2, "Last address should be addr2 after rolling");
    }

    function test_Add_MultipleRollovers() public {
        // using window = 5
        rolling.configureWindow(5);

        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);
        address addr3 = vm.addr(3);
        address addr4 = vm.addr(4);
        address addr5 = vm.addr(5);
        address addr6 = vm.addr(6);
        address addr7 = vm.addr(7);

        rolling.add(addr1); // out
        rolling.add(addr2); // out
        rolling.add(addr3);
        rolling.add(addr4);
        rolling.add(addr5);
        rolling.add(addr6);
        rolling.add(addr7);

        address[] memory got = rolling.getAll();
        address[] memory expected = new address[](5);
        expected[0] = addr3;
        expected[1] = addr4;
        expected[2] = addr5;
        expected[3] = addr6;
        expected[4] = addr7;

        assertEq(got, expected, "Expected addresses should match after multiple rollovers");
    }

    function test_Exists_ReturnTrueIfExists() public {
        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);
        address addr3 = vm.addr(3);
        address addr4 = vm.addr(4);
        address addr5 = vm.addr(5);
        address addr6 = vm.addr(6);

        // using default window
        rolling.add(addr1);
        rolling.add(addr2);
        rolling.add(addr3);
        rolling.add(addr4);
        rolling.add(addr5);
        rolling.add(addr6);

        // rolled out should return false
        assertFalse(rolling.exists(addr1), "Address should not exist after rolling out");
        assertFalse(rolling.exists(addr2), "Address should not exist after rolling out");
        assertFalse(rolling.exists(addr3), "Address should not exist after rolling out");
        assertTrue(rolling.exists(addr4), "Address should not exist after rolling out");
        assertTrue(rolling.exists(addr5), "Address should not exist after rolling out");
        assertTrue(rolling.exists(addr6), "Address should not exist after rolling out");
    }

    function test_Length_ReturnValidLen() public {
        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);

        rolling.add(addr1);
        rolling.add(addr2);
        assertEq(rolling.getLength(), 2, "Expected length should be 2");

        address addr3 = vm.addr(3);
        address addr4 = vm.addr(4);
        address addr5 = vm.addr(5);
        rolling.add(addr3);
        rolling.add(addr4);
        rolling.add(addr5);
        // do not grow; default window is 3
        // must keep the same window size
        assertEq(rolling.getLength(), 3, "Expected length should be 3 after rolling");
    }

    function test_At_ReturnCorrespondingValue() public {
        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);

        rolling.add(addr1);
        rolling.add(addr2);

        assertEq(rolling.getAt(0), addr1, "First address should be addr1");
        assertEq(rolling.getAt(1), addr2, "Second address should be addr2");
    }

    function test_At_ReturnLastElement() public {
        rolling.configureWindow(3);
        address addr1 = vm.addr(1);
        address addr2 = vm.addr(2);
        address addr3 = vm.addr(3);
        rolling.add(addr1);
        rolling.add(addr2);
        rolling.add(addr3);

        assertEq(rolling.getAt(2), addr3, "Last address should be addr3");
    }

    function test_At_RevertIf_InvalidIndex() public {
        address addr1 = vm.addr(1);
        rolling.add(addr1);
        // only index 0 existing
        vm.expectRevert();
        rolling.getAt(1);
    }
}
