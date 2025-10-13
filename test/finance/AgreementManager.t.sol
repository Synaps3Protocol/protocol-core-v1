// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { ILedgerVault } from "contracts/core/interfaces/financial/ILedgerVault.sol";
import { ILedgerVerifiable } from "@synaps3/core/interfaces/base/ILedgerVerifiable.sol";
import { IAgreementManager } from "contracts/core/interfaces/financial/IAgreementManager.sol";
import { AgreementManager } from "contracts/financial/AgreementManager.sol";
import { BaseTest } from "test/BaseTest.t.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { C } from "contracts/core/primitives/Constants.sol";

interface IAgreementManagerExtended is IAgreementManager {
    function maxParties() external view returns (uint256);
    function setMaxParties(uint256 newMax) external;
}

contract AgreementManagerMockArbiter {}

contract AgreementManagerTest is BaseTest {
    uint256 internal constant INITIAL_DEPOSIT = 1_000 * 1e18;
    address internal arbiter;

    function setUp() public initialize {
        deployAgreementManager();
        arbiter = address(new AgreementManagerMockArbiter());

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, arbiter, 500, token);

        vm.startPrank(admin);
        IERC20(token).approve(ledger, INITIAL_DEPOSIT);
        ILedgerVault(ledger).deposit(user, INITIAL_DEPOSIT, token);
        vm.stopPrank();
    }

    function _buildParties(uint256 len) private view returns (address[] memory parties) {
        parties = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            parties[i] = vm.addr(100 + i);
        }
    }

    function _penaltyBps(uint256 partiesLen, uint256 maxParties) private pure returns (uint256) {
        if (partiesLen <= maxParties) return 0;
        uint256 excess = partiesLen - maxParties;
        return ((excess * (excess + 1)) / 2) * 100;
    }

    function test_SetMaxParties_UpdatesValue() public {
        vm.prank(admin);
        IAgreementManagerExtended(agreementManager).setMaxParties(8);
        assertEq(IAgreementManagerExtended(agreementManager).maxParties(), 8, "maxParties should update");
    }

    function test_SetMaxParties_RevertWhen_Zero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(AgreementManager.InvalidMaxParties.selector, 0));
        IAgreementManagerExtended(agreementManager).setMaxParties(0);
    }

    function test_SetMaxParties_RevertWhen_NotAdmin() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidUnauthorizedOperation(string)", "Only admin can perform this action."));
        IAgreementManagerExtended(agreementManager).setMaxParties(6);
    }

    function test_CreateAgreement_StoresAgreement() public {
        uint256 amount = 50 * 1e18;
        address[] memory parties = _buildParties(2);
        bytes memory payload = abi.encode("agreement");

        vm.expectEmit(true, false, false, true, agreementManager);
        emit AgreementManager.AgreementCreated(user, 0, amount, token);

        vm.prank(user);
        uint256 proof = IAgreementManager(agreementManager).createAgreement(amount, token, arbiter, parties, payload);

        T.Agreement memory stored = IAgreementManager(agreementManager).getAgreement(proof);
        assertEq(stored.total, amount, "Total mismatch");
        assertEq(stored.initiator, user, "Initiator mismatch");
        assertEq(stored.arbiter, arbiter, "Arbiter mismatch");
        assertEq(stored.parties, parties, "Parties mismatch");
        assertEq(stored.payload, payload, "Payload mismatch");

        uint256 userLedger = ILedgerVerifiable(ledger).getLedgerBalance(user, token);
        assertEq(userLedger, INITIAL_DEPOSIT - stored.locked, "Ledger should reflect locked funds");
    }

    function test_CreateAgreement_RevertWhen_UnsupportedCurrency() public {
        address unsupportedArbiter = address(new AgreementManagerMockArbiter());
        address[] memory parties;

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(AgreementManager.UnsupportedAgreementTarget.selector, unsupportedArbiter, token));
        IAgreementManager(agreementManager).createAgreement(1e18, token, unsupportedArbiter, parties, "");
    }

    function test_CreateAgreement_RevertWhen_FlatFeeExceedsTotal() public {
        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.FLAT, arbiter, 20 * 1e18, token);

        address[] memory parties = _buildParties(1);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(AgreementManager.FlatFeeExceedsTotal.selector, 10 * 1e18, 20 * 1e18));
        IAgreementManager(agreementManager).createAgreement(10 * 1e18, token, arbiter, parties, "");
    }

    function test_CreateAgreement_RevertWhen_InsufficientBalance() public {
        address[] memory parties;
        uint256 amount = INITIAL_DEPOSIT + 1;

        vm.prank(user);
        vm.expectRevert(bytes4(keccak256("NoFundsToLock()")));
        IAgreementManager(agreementManager).createAgreement(amount, token, arbiter, parties, "");
    }

    function test_CreateAgreement_ComputesFeesForBpsScheme() public {
        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, arbiter, 500, token);

        uint256 amount = 200 * 1e18;
        address[] memory parties = _buildParties(1);

        vm.prank(user);
        uint256 proof = IAgreementManager(agreementManager).createAgreement(amount, token, arbiter, parties, "");

        T.Agreement memory stored = IAgreementManager(agreementManager).getAgreement(proof);
        uint256 expectedFee = (amount * 500) / C.BPS_MAX; // 500 bps configured in setUp
        assertEq(stored.fees, expectedFee, "BPS fee mismatch");
    }

    function test_CreateAgreement_ComputesFeesForNominalScheme() public {
        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.NOMINAL, arbiter, 25, token); // 25% nominal

        uint256 amount = 80 * 1e18;
        address[] memory parties = _buildParties(2);

        vm.prank(user);
        uint256 proof = IAgreementManager(agreementManager).createAgreement(amount, token, arbiter, parties, "");

        T.Agreement memory stored = IAgreementManager(agreementManager).getAgreement(proof);
        uint256 expectedFee = (amount * 25 * 100) / C.BPS_MAX; // nominal converted to bps internally
        assertEq(stored.fees, expectedFee, "Nominal fee mismatch");

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, arbiter, 500, token);
    }

    function test_CreateAgreement_RevertWhen_ExceedsMaxPartiesPenaltyCap() public {
        uint256 maxParties = IAgreementManagerExtended(agreementManager).maxParties();
        uint256 partiesLen = maxParties + 15; // ensures penalty bps > 10_000
        address[] memory parties = _buildParties(partiesLen);

        vm.prank(user);
        vm.expectRevert(AgreementManager.ExceedsMaxParties.selector);
        IAgreementManager(agreementManager).createAgreement(10 * 1e18, token, arbiter, parties, "");
    }

    function test_PreviewAgreement_NoPenalizationWhenWithinLimit() public {
        uint256 amount = 60 * 1e18;
        uint256 maxParties = IAgreementManagerExtended(agreementManager).maxParties();
        address[] memory parties = _buildParties(maxParties);

        vm.prank(user);
        T.Agreement memory preview = IAgreementManager(agreementManager).previewAgreement(amount, token, arbiter, parties, "");

        assertEq(preview.locked, amount, "Locked amount should equal total when within limit");
    }

    function test_CreateAgreement_WithPenalizationLocksAmount() public {
        uint256 partiesLen = IAgreementManagerExtended(agreementManager).maxParties() + 2;
        address[] memory parties = _buildParties(partiesLen);
        uint256 amount = 100 * 1e18;

        vm.prank(user);
        uint256 proof = IAgreementManager(agreementManager).createAgreement(amount, token, arbiter, parties, "");

        T.Agreement memory stored = IAgreementManager(agreementManager).getAgreement(proof);
        uint256 penaltyBps = _penaltyBps(partiesLen, IAgreementManagerExtended(agreementManager).maxParties());
        uint256 expectedLocked = amount + ((amount * penaltyBps) / C.BPS_MAX);

        assertEq(stored.locked, expectedLocked, "Locked amount mismatch");

        uint256 userLedger = ILedgerVerifiable(ledger).getLedgerBalance(user, token);
        assertEq(userLedger, INITIAL_DEPOSIT - stored.locked, "Ledger balance should reflect locked amount");
    }

    function test_PreviewAgreement_Penalization() public {
        uint256 partiesLen = 9;
        address[] memory parties = _buildParties(partiesLen);
        uint256 amount = 100 * 1e18;

        vm.prank(user);
        T.Agreement memory agreement = IAgreementManager(agreementManager).previewAgreement(amount, token, arbiter, parties, "");

        uint256 exceed = partiesLen - IAgreementManagerExtended(agreementManager).maxParties();
        uint256 expectedPercentage = (exceed * (exceed + 1)) / 2;
        uint256 expectedPenalization = (amount * expectedPercentage * 100) / C.BPS_MAX;

        assertEq(agreement.locked, amount + expectedPenalization, "Penalization mismatch");
    }

}
