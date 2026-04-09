// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { ILedgerVault } from "contracts/core/interfaces/financial/ILedgerVault.sol";
import { ILedgerVerifiable } from "@synaps3/core/interfaces/base/ILedgerVerifiable.sol";
import { IAgreementManager } from "contracts/core/interfaces/financial/IAgreementManager.sol";
import { IAgreementSettler } from "contracts/core/interfaces/financial/IAgreementSettler.sol";
import { AgreementSettler } from "contracts/financial/AgreementSettler.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

interface IAgreementManagerExtended is IAgreementManager {
    function maxParties() external view returns (uint256);
}

interface IAgreementSettlerExtended is IAgreementSettler {
    function quitAgreement(uint256 proof) external returns (T.Agreement memory);
}

contract SettlerMockArbiter {
    IAgreementSettler public immutable SETTLER;

    constructor(address settler) {
        SETTLER = IAgreementSettler(settler);
    }

    function execute(uint256 proof, address counterparty) external returns (T.Agreement memory) {
        return SETTLER.settleAgreement(proof, counterparty);
    }
}

contract AgreementSettlerTest is BaseTest {
    uint256 internal constant INITIAL_DEPOSIT = 5_000 * 1e18;
    SettlerMockArbiter arbiter;

    function setUp() public initialize {
        deployAgreementSettler();
        arbiter = new SettlerMockArbiter(agreementSettler);

        vm.startPrank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, address(arbiter), 500, token);
        IERC20(token).approve(ledger, INITIAL_DEPOSIT);
        ILedgerVault(ledger).deposit(user, INITIAL_DEPOSIT, token);
        vm.stopPrank();
    }

    function _penaltyBps(uint256 partiesLen, uint256 maxParties) private pure returns (uint256) {
        if (partiesLen <= maxParties) return 0;
        uint256 excess = partiesLen - maxParties;
        return ((excess * (excess + 1)) / 2) * 100;
    }

    function _buildParties(uint256 len) private view returns (address[] memory parties) {
        parties = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            parties[i] = vm.addr(1_100 + i);
        }
    }

    function _boundedAmount(uint256 seed, uint256 partiesLen) private view returns (uint256) {
        uint256 maxParties = IAgreementManagerExtended(agreementManager).maxParties();
        uint256 penalty = _penaltyBps(partiesLen, maxParties);
        uint256 available = ILedgerVerifiable(ledger).getLedgerBalance(user, token);
        uint256 maxAmount = available;
        if (penalty > 0) {
            maxAmount = (available * C.BPS_MAX) / (C.BPS_MAX + penalty);
        }
        if (maxAmount < 1e18) return 0;
        return bound(seed, 1e18, maxAmount);
    }

    function _createAgreement(uint256 amount, uint256 partiesLen) private returns (uint256 proof, T.Agreement memory stored) {
        address[] memory parties = _buildParties(partiesLen);
        vm.prank(user);
        proof = IAgreementManager(agreementManager).createAgreement(amount, token, address(arbiter), parties, "");
        stored = IAgreementManager(agreementManager).getAgreement(proof);
    }

    function test_SettleAgreement_DistributesFunds() public {
        uint256 amount = 150 * 1e18;
        (uint256 proof, T.Agreement memory agreement) = _createAgreement(amount, 4);
        address counterparty = vm.addr(5555);

        vm.expectEmit(true, true, true, true, agreementSettler);
        emit AgreementSettler.AgreementSettled(address(arbiter), counterparty, proof, agreement.fees + (agreement.locked - agreement.total));
        vm.prank(address(arbiter));
        T.Agreement memory settled = IAgreementSettlerExtended(agreementSettler).settleAgreement(proof, counterparty);

        uint256 available = settled.total - settled.fees;
        uint256 protocolTake = settled.fees + (settled.locked - settled.total);

        assertEq(ILedgerVerifiable(ledger).getLedgerBalance(counterparty, token), available, "Counterparty payout mismatch");
        assertEq(ILedgerVerifiable(ledger).getLedgerBalance(agreementSettler, token), protocolTake, "Protocol take mismatch");

        vm.expectRevert(AgreementSettler.AgreementAlreadySettled.selector);
        arbiter.execute(proof, counterparty);
    }

    function test_SettleAgreement_RevertWhen_NotArbiter() public {
        uint256 amount = 10 * 1e18;
        (uint256 proof, ) = _createAgreement(amount, 0);

        vm.expectRevert(AgreementSettler.UnauthorizedEscrowAgent.selector);
        IAgreementSettler(agreementSettler).settleAgreement(proof, vm.addr(999));
    }

    function test_QuitAgreement_ReleasesFunds() public {
        uint256 amount = 75 * 1e18;
        (uint256 proof, T.Agreement memory agreement) = _createAgreement(amount, 6);

        uint256 protocolTake = agreement.fees + (agreement.locked - agreement.total);

        vm.prank(user);
        vm.expectEmit(true, false, true, true, agreementSettler);
        emit AgreementSettler.AgreementCancelled(user, proof, protocolTake);
        T.Agreement memory cancelled = IAgreementSettlerExtended(agreementSettler).quitAgreement(proof);

        assertEq(cancelled.total, agreement.total, "Quit agreement mismatch");
        assertEq(ILedgerVerifiable(ledger).getLedgerBalance(agreementSettler, token), protocolTake, "Protocol take mismatch");
        assertEq(
            ILedgerVerifiable(ledger).getLedgerBalance(user, token),
            INITIAL_DEPOSIT - protocolTake,
            "User ledger mismatch"
        );

        vm.prank(user);
        vm.expectRevert(AgreementSettler.AgreementAlreadySettled.selector);
        IAgreementSettlerExtended(agreementSettler).quitAgreement(proof);
    }

    function test_SettleAgreement_RevertWhen_AlreadySettled() public {
        uint256 amount = 60 * 1e18;
        (uint256 proof, ) = _createAgreement(amount, 2);
        address counterparty = vm.addr(7001);

        vm.prank(address(arbiter));
        IAgreementSettlerExtended(agreementSettler).settleAgreement(proof, counterparty);

        vm.expectRevert(AgreementSettler.AgreementAlreadySettled.selector);
        vm.prank(address(arbiter));
        IAgreementSettlerExtended(agreementSettler).settleAgreement(proof, counterparty);
    }

    function test_QuitAgreement_RevertWhen_NotInitiator() public {
        uint256 amount = 30 * 1e18;
        (uint256 proof, ) = _createAgreement(amount, 1);

        vm.expectRevert(AgreementSettler.UnauthorizedInitiator.selector);
        vm.prank(vm.addr(3333));
        IAgreementSettlerExtended(agreementSettler).quitAgreement(proof);
    }

    function test_QuitAgreement_RevertWhen_AlreadySettled() public {
        uint256 amount = 90 * 1e18;
        (uint256 proof, ) = _createAgreement(amount, 2);

        vm.prank(address(arbiter));
        IAgreementSettlerExtended(agreementSettler).settleAgreement(proof, vm.addr(9000));

        vm.expectRevert(AgreementSettler.AgreementAlreadySettled.selector);
        vm.prank(user);
        IAgreementSettlerExtended(agreementSettler).quitAgreement(proof);
    }

}
