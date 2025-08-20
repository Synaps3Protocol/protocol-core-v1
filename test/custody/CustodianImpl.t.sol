// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ICustodian } from "contracts/core/interfaces/custody/ICustodian.sol";
import { IBalanceVerifiable } from "contracts/core/interfaces/base/IBalanceVerifiable.sol";
import { IBalanceWithdrawable } from "contracts/core/interfaces/base/IBalanceWithdrawable.sol";
import { ICustodianFactory } from "contracts/core/interfaces/custody/ICustodianFactory.sol";
import { BaseTest } from "test/BaseTest.t.sol";

contract CustodianImplTest is BaseTest {
    function setUp() public initialize {
        deployToken();
        deployCustodianFactory();
    }

    function deployCustodian(string memory endpoint, address owner) public returns (address) {
        vm.prank(owner);
        ICustodianFactory factory = ICustodianFactory(custodianFactory);
        return factory.create(endpoint);
    }

    function testFuzz_Create_ValidCustodian(string memory endpoint) public {
        vm.assume(bytes(endpoint).length > 0);

        address custodian = deployCustodian(endpoint, user);
        bool supportedInterface = IERC165(custodian).supportsInterface(type(ICustodian).interfaceId);
        assertEq(supportedInterface, true, "Custodian should support ICustodian interface");
    }

    function testFuzz_GetOwner_ExpectedDeployer(address manager, string memory endpoint) public {
        vm.assume(manager != address(0));
        vm.assume(bytes(endpoint).length > 0);
        vm.assume(manager.code.length == 0);

        address custodian = deployCustodian(endpoint, manager);
        address currentManager = ICustodian(custodian).getManager();
        assertEq(currentManager, manager, "Expected owner should be the deployer");
    }

    function testFuzz_GetEndpoint_ExpectedEndpoint(string memory endpoint) public {
        vm.assume(bytes(endpoint).length > 0);

        address custodian = deployCustodian(endpoint, user);
        string memory got = ICustodian(custodian).getEndpoint();
        assertEq(endpoint, got, "Expected endpoint should match");
    }

    function test_SetEndpoint_ValidEndpoint() public {
        // created with an initial endpoint
        address custodian = deployCustodian("1.1.1.1", user);
        vm.prank(user); // only owner can do this
        ICustodian(custodian).setEndpoint("mynew.com");
        string memory endpoint = ICustodian(custodian).getEndpoint();
        assertEq(endpoint, "mynew.com", "Expected endpoint should be updated");
    }

    function test_SetEndpoint_RevertWhen_InvalidOwner() public {
        // created with an initial endpoint
        address custodian = deployCustodian("1.1.1.1", user);
        address invalidOwner = vm.addr(10);

        vm.prank(invalidOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", invalidOwner));
        ICustodian(custodian).setEndpoint("mynew.com");
    }

    function test_GetBalance_ValidBalance() public {
        // created with an initial endpoint
        address custodian = deployCustodian("1.1.1.1", user);
        uint256 expected = 100 * 1e18;
        // admin acting as reward system to transfer funds
        // here the expected is that rewards system do it.
        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(custodian, expected);
        uint256 currentBalance = IBalanceVerifiable(custodian).getBalance(token);
        assertEq(currentBalance, expected, "Expected balance should match");
        vm.stopPrank();
    }

    function test_Withdraw_ValidFundsWithdrawn() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1", admin);

        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(custodian, expected);
        // only owner can withdraw funds by default deployer
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
        vm.stopPrank();

        uint256 userBalance = IERC20(token).balanceOf(user);
        assertEq(userBalance, expected, "User should receive the withdrawn funds");
    }

    function test_Withdraw_EmitFundsWithdrawn() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1", admin);

        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(custodian, expected);
        // only owner can withdraw funds by default deployer
        vm.expectEmit(true, true, false, true, address(custodian));
        emit IBalanceWithdrawable.FundsWithdrawn(user, admin, expected, token);
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
        vm.stopPrank();

        assertEq(IERC20(token).balanceOf(user), expected, "user with funds");
        assertEq(IERC20(token).balanceOf(custodian), 0, "custodian must be zero");
    }

    function test_Withdraw_RevertWhen_NoBalance() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1", user);

        vm.prank(user); // only owner can get balance by default deployer
        vm.expectRevert(abi.encodeWithSignature("NoFundsToWithdraw()"));
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
    }

    function test_Withdraw_RevertWhen_InvalidOwner() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1", user);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
    }
}
