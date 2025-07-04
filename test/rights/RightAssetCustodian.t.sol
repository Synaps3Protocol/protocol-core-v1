// calc weight based on expected balance, demand and priority
// get balanced custodian with a expected proba
//

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IRightsAssetCustodianManager } from "contracts/core/interfaces/rights/IRightsAssetCustodianManager.sol";
import { IRightsAssetCustodianVerifiable } from "contracts/core/interfaces/rights/IRightsAssetCustodianVerifiable.sol";
import { IRightsAssetCustodianRegistrable } from "contracts/core/interfaces/rights/IRightsAssetCustodianRegistrable.sol";
import { ICustodianVerifiable } from "contracts/core/interfaces/custody/ICustodianVerifiable.sol";
import { ICustodianRevokable } from "contracts/core/interfaces/custody/ICustodianRevokable.sol";
import { IBalanceVerifiable } from "contracts/core/interfaces/base/IBalanceVerifiable.sol";
import { RightsAssetCustodian } from "contracts/rights/RightsAssetCustodian.sol";
import { CustodianShared } from "test/shared/CustodianShared.t.sol";

contract RightAssetCustodianTest is CustodianShared {
    using Math for uint256;
    address custodian;

    function setUp() public override {
        super.setUp();
        custodian = deployCustodian("weare.com");
        _registerAndApproveCustodian(custodian);
        deployRightsAssetCustodian();
        deployToken();
    }

    function test_SetMaxAllowedRedundancy_ValidValue() public {
        vm.startPrank(admin);
        uint256 newMaxRedundancy = 5;
        IRightsAssetCustodianManager(rightAssetCustodian).setMaxAllowedRedundancy(newMaxRedundancy);
        uint256 maxRedundancy = IRightsAssetCustodianManager(rightAssetCustodian).getMaxAllowedRedundancy();
        assertEq(maxRedundancy, newMaxRedundancy, "Max allowed redundancy should be updated");
        vm.stopPrank();
    }

    function test_SetMaxAllowedRedundancy_RevertIf_NotAuthorized() public {
        vm.startPrank(user);
        uint256 newMaxRedundancy = 5;
        vm.expectRevert(abi.encodeWithSignature("AccessManagedUnauthorized(address)", user));
        IRightsAssetCustodianManager(rightAssetCustodian).setMaxAllowedRedundancy(newMaxRedundancy);
        vm.stopPrank();
    }

    function test_GrantCustody_ValidCustodian() public {
        vm.prank(user);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        bool isCustodian = IRightsAssetCustodianVerifiable(rightAssetCustodian).isCustodian(custodian, user);
        assertTrue(isCustodian, "Custodian should be registered");
    }

    function test_GrantCustody_EmitCustodialGranted() public {
        vm.prank(user);

        vm.expectEmit(true, true, false, true, address(rightAssetCustodian));
        emit RightsAssetCustodian.CustodialGranted(custodian, user, 1);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
    }

    function test_GrantCustody_RevertIf_GrantDuplication() public {
        vm.startPrank(user);
        // registered first time
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        uint256 demand = IRightsAssetCustodianManager(rightAssetCustodian).getDemand(custodian);
        assertEq(demand, 1, "Demand should be 1 after granting custody");

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

    function test_RevokeCustody_ValidRegisteredCustodian() public {
        vm.prank(user);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).revokeCustody(custodian);
        bool isCustodian = IRightsAssetCustodianVerifiable(rightAssetCustodian).isCustodian(custodian, user);
        assertFalse(isCustodian, "Custodian should be revoked");
    }

    function test_RevokeCustody_EmitCustodialRevoked() public {
        vm.startPrank(user);
        // first grant the custody
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);

        vm.expectEmit(true, true, false, true, address(rightAssetCustodian));
        emit RightsAssetCustodian.CustodialRevoked(custodian, user, 0);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).revokeCustody(custodian);
        vm.stopPrank();
    }

    function test_RevokeCustody_RevertIf_NotRegisteredCustodian() public {
        vm.startPrank(user);
        // registered first time
        uint256 demand = IRightsAssetCustodianManager(rightAssetCustodian).getDemand(custodian);
        assertEq(demand, 0, "Demand should be 0 before granting custody");

        // second expected failing attempt
        vm.expectRevert(abi.encodeWithSignature("RevokeCustodyFailed(address,address)", custodian, user));
        IRightsAssetCustodianRegistrable(rightAssetCustodian).revokeCustody(custodian);
        vm.stopPrank();
    }

    function test_SetPriority_EmitPrioritySet() public {
        // second expected failing attempt
        uint256 designedPriority = 2;
        address custodian2 = deployCustodian("weare1.com");

        vm.startPrank(user);
        vm.expectEmit(true, true, false, true, address(rightAssetCustodian));
        emit RightsAssetCustodian.PrioritySet(custodian2, user, designedPriority);
        IRightsAssetCustodianManager(rightAssetCustodian).setPriority(custodian2, designedPriority);
        vm.stopPrank();
    }

    function test_SetPriority_ValidPriority() public {
        // second expected failing attempt
        uint256 designedPriority = 2;
        address custodian2 = deployCustodian("weare1.com");

        vm.prank(user);
        IRightsAssetCustodianManager(rightAssetCustodian).setPriority(custodian2, designedPriority);
        uint256 got = IRightsAssetCustodianManager(rightAssetCustodian).getPriority(custodian2, user);
        assertEq(got, designedPriority, "Priority should be set correctly");
    }

    function test_SetPriority_RevertIf_ValidPriority() public {
        // second expected failing attempt
        address custodian2 = deployCustodian("weare1.com");
        vm.expectRevert(abi.encodeWithSignature("InvalidPriority(uint256)", 0));
        IRightsAssetCustodianManager(rightAssetCustodian).setPriority(custodian2, 0);
    }

    function test_GetDemand_ReturnValidDemand() public {
        uint256 before = IRightsAssetCustodianManager(rightAssetCustodian).getDemand(custodian);
        assertEq(before, 0, "Demand should be 0 before granting custody");

        vm.prank(user);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        uint256 after_ = IRightsAssetCustodianManager(rightAssetCustodian).getDemand(custodian);
        assertEq(after_, 1, "Demand should be 1 after granting custody");

        vm.prank(user);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).revokeCustody(custodian);
        uint256 revoked = IRightsAssetCustodianManager(rightAssetCustodian).getDemand(custodian);
        assertEq(revoked, 0, "Demand should be 0 after revoked custody");
    }

    function test_GetWeight_ValidExpectedWeight() public {
        address user1 = vm.addr(4);
        IRightsAssetCustodianManager rightAssetCustodianMgr = IRightsAssetCustodianManager(rightAssetCustodian);
        IRightsAssetCustodianRegistrable rightAssetCustodianReg = IRightsAssetCustodianRegistrable(rightAssetCustodian);
        // expected d = 2
        vm.prank(user); // user grant custody
        rightAssetCustodianReg.grantCustody(custodian);
        vm.prank(user1);
        rightAssetCustodianReg.grantCustody(custodian);

        // expected b = log2(10000)
        vm.prank(admin);
        IERC20(token).transfer(custodian, 10000);
        // expected p = 2
        vm.prank(user);
        rightAssetCustodianMgr.setPriority(custodian, 2);

        // calc weight for user
        uint256 b = IBalanceVerifiable(custodian).getBalance(token);
        uint256 p = rightAssetCustodianMgr.getPriority(custodian, user);
        uint256 d = rightAssetCustodianMgr.getDemand(custodian);
        uint256 expectedWeight = rightAssetCustodianMgr.getWeight(custodian, user, token);
        uint256 w = p * (d + 1) * (b.log2() + 1);

        assertEq(w, 84, "Weight should match the expected formula");
        assertEq(w, expectedWeight, "Weight should match the expected formula");

        //
    }

    function test_GetCustodian_ValidGrantedCustodian() public {
        address custodian2 = deployCustodian("weare1.com");
        address custodian3 = deployCustodian("weare2.com");

        address user1 = vm.addr(4);
        IRightsAssetCustodianManager rightAssetCustodianMgr = IRightsAssetCustodianManager(rightAssetCustodian);
        IRightsAssetCustodianRegistrable rightAssetCustodianReg = IRightsAssetCustodianRegistrable(rightAssetCustodian);

        // simulate approval process
        _registerAndApproveCustodian(custodian2);
        _registerAndApproveCustodian(custodian3);

        // expected d = 2
        // higher demand for 'custodian'
        vm.prank(user1);
        rightAssetCustodianReg.grantCustody(custodian);
        vm.startPrank(user);
        // assign custodians to user
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian2);
        IRightsAssetCustodianRegistrable(rightAssetCustodian).grantCustody(custodian3);
        vm.stopPrank();

        // 1- sum the weights
        uint256 total = 0;
        uint256[] memory weights = new uint256[](3);
        address[] memory custodians = new address[](3);
        custodians[0] = custodian;
        custodians[1] = custodian2;
        custodians[2] = custodian3;

        for (uint256 i = 0; i < custodians.length; i++) {
            uint256 w = rightAssetCustodianMgr.getWeight(custodians[i], user, token);
            weights[i] = w;
            total += w;
        }

        // simulate the internal behavior of getCustodian
        // given the block A, the holder X and currency Z
        vm.roll(10); // initialize in block 10
        // same block number derive deterministic in the same blockhash
        // same hash + user + token derive in the same randomSeed
        bytes32 blockHash = blockhash(block.number - 1);
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(blockHash, user, token)));
        // same modulus with same randomSeed and total derive deterministic in the same randomValue
        // the randomValue is in range [0, total]
        uint256 randomValue = randomSeed % total;
        uint256 acc = 0;

        // the same data is used to derive the custodian in deterministic way
        // must match exact the same custodian during categorical selection
        address selectedCustodian = rightAssetCustodianMgr.getCustodian(user, token);
        // iterate through the weights and custodians to find the selected custodian
        for (uint256 i = 0; i < weights.length; i++) {
            uint256 weight = weights[i];
            acc += weight;

            // assert the matched in the hit range
            if (randomValue < acc) {
                assertEq(selectedCustodian, custodians[i], "Selected custodian should match the expected one");
                break;
            }
        }
    }

    function test_IsCustodian_ReturnFalseIfRevokedNorExist() public {
        // MAX default = 3
        address custodian2 = deployCustodian("weare1.com");
        IRightsAssetCustodianVerifiable rightAssetCustodianVer = IRightsAssetCustodianVerifiable(rightAssetCustodian);
        IRightsAssetCustodianRegistrable rightAssetCustodianReg = IRightsAssetCustodianRegistrable(rightAssetCustodian);

        vm.prank(user);
        rightAssetCustodianReg.grantCustody(custodian);
        bool isCustodian = rightAssetCustodianVer.isCustodian(custodian, user);
        bool isFalseCustodian = rightAssetCustodianVer.isCustodian(custodian2, user);

        vm.prank(user);
        rightAssetCustodianReg.revokeCustody(custodian);
        bool isRevokedCustodian = rightAssetCustodianVer.isCustodian(custodian2, user);

        assertTrue(isCustodian, "Custodian should be registered after grant");
        assertFalse(isFalseCustodian, "Custodian should not be registered");
        assertFalse(isRevokedCustodian, "Custodian should not be registered after revoke");
    }

    function test_IsCustodian_ReturnFalseIfRevokedByGovernance() public {
        // MAX default = 3
        IRightsAssetCustodianVerifiable rightAssetCustodianVer = IRightsAssetCustodianVerifiable(rightAssetCustodian);
        IRightsAssetCustodianRegistrable rightAssetCustodianReg = IRightsAssetCustodianRegistrable(rightAssetCustodian);

        vm.prank(user);
        //custody granted
        rightAssetCustodianReg.grantCustody(custodian);
        bool isCustodian = rightAssetCustodianVer.isCustodian(custodian, user);
        assertTrue(isCustodian, "Custodian should be registered");

        vm.prank(governor);
        ICustodianRevokable(custodianReferendum).revoke(custodian);
        bool isRevokedCustodian = rightAssetCustodianVer.isCustodian(custodian, user);
        assertFalse(isRevokedCustodian, "Custodian should not be registered after revocation by governance");
    }

    // TODO assign demand + transfer balance and check calc of weight
}
