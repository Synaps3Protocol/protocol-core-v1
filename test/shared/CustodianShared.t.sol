// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { BaseTest } from "test/BaseTest.t.sol";
import { ICustodianFactory } from "contracts/core/interfaces/custody/ICustodianFactory.sol";
import { ICustodianRegistrable } from "contracts/core/interfaces/custody/ICustodianRegistrable.sol";
import { IAgreementManager } from "contracts/core/interfaces/financial/IAgreementManager.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { ILedgerVault } from "contracts/core/interfaces/financial/ILedgerVault.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { T } from "contracts/core/primitives/Types.sol";

contract CustodianShared is BaseTest {
    function setUp() public virtual initialize {
        deployCustodianReferendum();
        deployCustodianFactory();
    }

    function _deployCustodian(string memory endpoint, address owner) internal returns (address) {
        vm.prank(owner);
        ICustodianFactory custodianFactory = ICustodianFactory(custodianFactory);
        return custodianFactory.create(endpoint);
    }

    function _registerAndApproveCustodian(address custodian) internal {
        _registerCustodian(custodian);
        vm.prank(nodesCouncil); // as governor.
        ICustodianRegistrable(custodianReferendum).approve(custodian);
    }

    function _registerCustodian(address custodian) internal {
        ICustodianRegistrable(custodianReferendum).register(custodian);
    }
  
}
