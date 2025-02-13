// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IDistributor } from "contracts/core/interfaces/syndication/IDistributor.sol";
import { IBalanceVerifiable } from "contracts/core/interfaces/base/IBalanceVerifiable.sol";
import { IBalanceWithdrawable } from "contracts/core/interfaces/base/IBalanceWithdrawable.sol";
import { IDistributorFactory } from "contracts/core/interfaces/syndication/IDistributorFactory.sol";
import { BaseTest } from "test/BaseTest.t.sol";

contract DistributorImplTest is BaseTest {
    address token;
    address distFactory;

    function setUp() public initialize {
        token = deployToken();
        distFactory = deployDistributorFactory();
    }

    function deployDistributor(string memory endpoint) public returns(address) {
        vm.prank(admin);
        IDistributorFactory distributorFactory = IDistributorFactory(distFactory);
        return distributorFactory.create(endpoint);
    }

    function test_Create_ValidDistributor() public {
        address distributor = deployDistributor("test.com");
        assertEq(IERC165(distributor).supportsInterface(type(IDistributor).interfaceId), true);
    }

    function test_GetOwner_ExpectedDeployer() public {
        address distributor = deployDistributor("test2.com");
        assertEq(IDistributor(distributor).getManager(), admin);
    }

    function test_GetEndpoint_ExpectedEndpoint() public {
        address distributor = deployDistributor("test3.com");
        assertEq(IDistributor(distributor).getEndpoint(), "test3.com");
    }

    function test_SetEndpoint_ValidEndpoint() public {
        // created with an initial endpoint
        address distributor = deployDistributor("1.1.1.1");
        // changed to a dns domain
        vm.prank(admin); // only owner can do this
        IDistributor(distributor).setEndpoint("mynew.com");
        assertEq(IDistributor(distributor).getEndpoint(), "mynew.com");
    }

    function test_SetEndpoint_RevertWhen_InvalidOwner() public {
        // created with an initial endpoint
        address distributor = deployDistributor("1.1.1.1");
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        IDistributor(distributor).setEndpoint("mynew.com");
    }

    function test_GetBalance_ValidBalance() public {
        // created with an initial endpoint
        address distributor = deployDistributor("1.1.1.1");
        uint256 expected = 100 * 1e18;
        // admin acting as reward system to transfer funds
        // here the expected is that rewards system do it.
        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(distributor, expected);
        assertEq(IBalanceVerifiable(distributor).getBalance(token), expected);
        vm.stopPrank();
    }

    function test_Withdraw_ValidFundsWithdrawn() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address distributor = deployDistributor("1.1.1.1");

        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(distributor, expected);
        // only owner can withdraw funds by default deployer
        IBalanceWithdrawable(distributor).withdraw(user, expected, token);
        vm.stopPrank();

        assertEq(IERC20(token).balanceOf(user), expected);
    }

    function test_Withdraw_EmitFundsWithdrawn() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address distributor = deployDistributor("1.1.1.1");

        vm.startPrank(admin); // only owner can get balance by default deployer
        IERC20(token).transfer(distributor, expected);
        // only owner can withdraw funds by default deployer
        vm.expectEmit(true, true, false, true, address(distributor));
        emit IBalanceWithdrawable.FundsWithdrawn(user, admin, expected, token);
        IBalanceWithdrawable(distributor).withdraw(user, expected, token);
    }

    function test_Withdraw_RevertWhen_NoBalance() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address distributor = deployDistributor("1.1.1.1");

        vm.startPrank(admin); // only owner can get balance by default deployer
        vm.expectRevert(abi.encodeWithSignature("NoFundsToWithdraw()"));
        IBalanceWithdrawable(distributor).withdraw(user, expected, token);
    }

    function test_Withdraw_RevertWhen_InvalidOwner() public {
        // created with an initial endpoint
        uint256 expected = 100 * 1e18;
        address distributor = deployDistributor("1.1.1.1");

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        IBalanceWithdrawable(distributor).withdraw(user, expected, token);
    }
}
