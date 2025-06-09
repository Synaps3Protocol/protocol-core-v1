// calc weight based on expected balance, demand and priority
// get balanced custodian with a expected proba
//

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IRightsAssetCustodianVerifiable } from "contracts/core/interfaces/rights/IRightsAssetCustodianVerifiable.sol";
import { IRightsAssetCustodianRegistrable } from "contracts/core/interfaces/rights/IRightsAssetCustodianRegistrable.sol";
import { ICustodianVerifiable } from "contracts/core/interfaces/custody/ICustodianVerifiable.sol";
import { IBalanceVerifiable } from "contracts/core/interfaces/base/IBalanceVerifiable.sol";
import { RightsAssetCustodian } from "contracts/rights/RightsAssetCustodian.sol";
import { CustodianShared } from "test/shared/CustodianShared.t.sol";

contract RightAssetCustodianTest is CustodianShared {
    // TODO evaluar gas report para analizar los fees en los tests

    address custodian;

    function setUp() public override {
        super.setUp();
        custodian = deployCustodian("weare.com");
        _registerAndApproveCustodian(custodian);
        deployRightsAssetCustodian();
    }

    function test_GrantCustody_ValidCustodian() public {
        vm.prank(user);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        bool isCustodian = IRightsAssetCustodianVerifiable(rightAssetCustodian).isCustodian(custodian, user);
        assertTrue(isCustodian, "Custodian should be registered");

        //  Verify the demand count
        uint256 demand = IRightsAssetCustodianVerifiable(rightAssetCustodian).getCustodyCount(custodian);
        assertEq(demand, 1, "Demand count should be incremented");
    }

    function test_GrantCustody_EmitCustodialGranted() public {
        vm.prank(user);

        vm.expectEmit(true, true, true, false, address(rightAssetCustodian));
        emit RightsAssetCustodian.CustodialGranted(custodian, user, 1);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
    }

    function test_GrantCustody_RevertIf_GrantDuplication() public {
        vm.startPrank(user);
        // registered first time
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        uint256 demand = IRightsAssetCustodianVerifiable(rightAssetCustodian).getCustodyCount(custodian);
        assertEq(demand, 1);

        // second expected failing attempt
        vm.expectRevert(abi.encodeWithSignature("GrantCustodyFailed(address,address)", custodian, user));
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        vm.stopPrank();
    }

    function test_GrantCustody_RevertIf_ExceedAvailableRedundancy() public {
        // MAX default = 3
        address custodian2 = deployCustodian("weare1.com");
        address custodian3 = deployCustodian("weare2.com");
        address custodian4 = deployCustodian("weare3.com");
         _registerAndApproveCustodian(custodian2);
        _registerAndApproveCustodian(custodian3);

        vm.startPrank(user);
        // registered first time
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian2);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian3);
        // 3 is reached, he validation is effective after this line

        // second expected failing attempt
        vm.expectRevert(abi.encodeWithSignature("MaxRedundancyAllowedReached()"));
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian4);
        vm.stopPrank();
    }

     function test_GrantCustody_RevertIf_InactiveNorRegisteredCustodian() public {
        // MAX default = 3
        address custodian2 = deployCustodian("weare1.com");
        // second expected failing attempt
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidInactiveCustodian()"));
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian2);
    }
}
