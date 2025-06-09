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

    function deployCustodian(string memory endpoint) public returns (address) {
        vm.prank(admin);
        ICustodianFactory custodianFactory = ICustodianFactory(custodianFactory);
        return custodianFactory.create(endpoint);
    }

    function _setFeesAsGovernor(uint256 fees) internal {
        vm.startPrank(governor);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, custodianReferendum, fees, token);
        vm.stopPrank();
    }

    function _registerCustodianWithApproval(address d9r, uint256 approval) internal {
        // manager = contract deployer
        // only manager can pay enrollment..
        vm.startPrank(admin);
        // approve approval to ledger to deposit funds
        address[] memory parties = new address[](1);
        parties[0] = d9r;

        uint256 proof = _createAgreement(approval, parties);
        // operate over msg.sender ledger registered funds
        ICustodianRegistrable(custodianReferendum).register(proof, d9r);
        vm.stopPrank();
    }

    function _createAgreement(uint256 amount, address[] memory parties) internal returns (uint256) {
        IERC20(token).approve(ledger, amount);
        ILedgerVault(ledger).deposit(admin, amount, token);

        uint256 proof = IAgreementManager(agreementManager).createAgreement(
            amount,
            token,
            address(custodianReferendum),
            parties,
            ""
        );

        return proof;
    }

    function _registerAndApproveCustodian(address d9r) internal {
        // intially the balance = 0
        _setFeesAsGovernor(1 * 1e18);
        // register the custodian with fees = 100 MMC
        _registerCustodianWithApproval(d9r, 1 * 1e18);
        vm.prank(governor); // as governor.
        // distribuitor approved only by governor..
        ICustodianRegistrable(custodianReferendum).approve(d9r);
    }
}
