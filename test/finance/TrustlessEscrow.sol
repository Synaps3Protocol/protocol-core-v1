// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";
import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { IAgreementManager } from "@synaps3/core/interfaces/financial/IAgreementManager.sol";
import { IAgreementSettler } from "@synaps3/core/interfaces/financial/IAgreementSettler.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

contract MockArbiter {
    IAgreementSettler public immutable AGREEMENT_SETTLER;

    constructor(address agreementSettler) {
        AGREEMENT_SETTLER = IAgreementSettler(agreementSettler);
    }

    function executeAgreement(uint256 proof, address counterparty) external returns (T.Agreement memory agreement) {
        agreement = AGREEMENT_SETTLER.settleAgreement(proof, counterparty);
    }
}

contract TrustlessEscrowTest is BaseTest {
    MockArbiter arbiter;

    function setUp() public initialize {
        deployAgreementSettler();
        arbiter = MockArbiter(agreementSettler);

        uint256 fees = 500; // 5%
        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, address(arbiter), fees, token);

        vm.startPrank(admin);

        uint256 amount = 100 * 1e18;
        IERC20(token).approve(ledger, amount);
        ILedgerVault(ledger).deposit(user, amount, token);
        vm.stopPrank();
    }

    function test_PreviewAgreement_ReturnExpectedAgreement() public {
        uint256 amount = 10 * 1e18;
        IAgreementManager manager = IAgreementManager(agreementManager);
        (uint256 feesBPS, ) = ITollgate(tollgate).getFees(address(arbiter),token);

        address[] memory parties = new address[](2);
        parties[0] = vm.addr(1);
        parties[1] = vm.addr(2);

        vm.prank(user);
        T.Agreement memory agreement = manager.previewAgreement(amount, token, address(arbiter), parties, "");
        uint256 fees = (feesBPS * amount) / 10_000; // 5% configured

        assertEq(agreement.total, amount);
        assertEq(agreement.initiator, user);
        assertEq(agreement.fees, fees);
        assertEq(agreement.locked, amount); // eq amount if not exceed allowed parties
        assertEq(agreement.currency, token);
        assertEq(agreement.arbiter, address(arbiter));
        assertEq(agreement.parties, parties);
        assertEq(agreement.payload, "");
    }

    function testFuzz_PreviewAgreement_ReturnPenalizedAgreement(uint256 partiesLen) public {
        uint256 amount = 100 * 1e18;
        // max 18 are allowed with soft cap maxParties = 5
        // force penalization with min 6, maxParties + 13 = 18
        uint256 capped = bound(partiesLen, 6, 18); 
        IAgreementManager manager = IAgreementManager(agreementManager);

        // max is 5, per each extra 1% in accumulated succession,
        // eg: 6, 7, 8 = 1 + 2 + 3 = 6% penalization
        address[] memory parties = new address[](capped);
        for (uint256 i = 0; i < capped; i++) {
            parties[i] = vm.addr(i + 1);
        }

        T.Agreement memory agreement = manager.previewAgreement(amount, token, address(arbiter), parties, "");

        uint256 exceed = capped - 5; // default maxParties = 5;
        uint256 expectedPercentage = (exceed * (exceed + 1)) / 2;
        uint256 expectedPenalizationBPS = expectedPercentage * 100;
        uint256 expectedPenalizationAmount = (amount * expectedPenalizationBPS) / C.BPS_MAX;
        uint256 expectedLocked = amount + expectedPenalizationAmount;

        assertEq(agreement.total, amount);
        assertEq(agreement.locked, expectedLocked);
        assertEq(agreement.parties, parties);
    }
}
