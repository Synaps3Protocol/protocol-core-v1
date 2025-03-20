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
    address token;
    address distFactory;

    function setUp() public initialize {
        token = deployToken();
        distFactory = deployCustodianFactory();
    }

    function deployCustodian(string memory endpoint) public returns(address) {
        vm.prank(admin);
        ICustodianFactory custodianFactory = ICustodianFactory(distFactory);
        return custodianFactory.create(endpoint);
    }

    function test_Create_ValidCustodian() public {
        address custodian = deployCustodian("test.com");
        assertEq(IERC165(custodian).supportsInterface(type(ICustodian).interfaceId), true);
    }

    function test_GetOwner_ExpectedDeployer() public {
        address custodian = deployCustodian("test2.com");
        assertEq(ICustodian(custodian).getManager(), admin);
    }

    function test_GetEndpoint_ExpectedEndpoint() public {
        address custodian = deployCustodian("test3.com");
        assertEq(ICustodian(custodian).getEndpoint(), "test3.com");
    }

    function test_SetEndpoint_ValidEndpoint() public {
        // created with an initial endpoint
        address custodian = deployCustodian("1.1.1.1");
        // changed to a dns domain
        vm.prank(admin); // only owner can do this
        ICustodian(custodian).setEndpoint("mynew.com");
        assertEq(ICustodian(custodian).getEndpoint(), "mynew.com");
    }

    function test_SetEndpoint_RevertWhen_InvalidOwner() public {
        // created with an initial endpoint
        address custodian = deployCustodian("1.1.1.1");
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        ICustodian(custodian).setEndpoint("mynew.com");
    }

    function test_GetBalance_ValidBalance() public {
        // created with an initial endpoint
        address custodian = deployCustodian("1.1.1.1");
        uint256 expected = 100 * 1e18;
        // admin acting as reward system to transfer funds
        // here the expected is that rewards system do it.
        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(custodian, expected);
        assertEq(IBalanceVerifiable(custodian).getBalance(token), expected);
        vm.stopPrank();
    }

    function test_Withdraw_ValidFundsWithdrawn() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1");

        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(custodian, expected);
        // only owner can withdraw funds by default deployer
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
        vm.stopPrank();

        assertEq(IERC20(token).balanceOf(user), expected);
    }

    function test_Withdraw_EmitFundsWithdrawn() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1");

        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(custodian, expected);
        // only owner can withdraw funds by default deployer
        vm.expectEmit(true, true, false, true, address(custodian));
        emit IBalanceWithdrawable.FundsWithdrawn(user, admin, expected, token);
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
    }

    function test_Withdraw_RevertWhen_NoBalance() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1");

        vm.startPrank(admin); // only owner can get balance by default deployer
        vm.expectRevert(abi.encodeWithSignature("NoFundsToWithdraw()"));
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
    }

    function test_Withdraw_RevertWhen_InvalidOwner() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address custodian = deployCustodian("1.1.1.1");

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        IBalanceWithdrawable(custodian).withdraw(user, expected, token);
    }
}
