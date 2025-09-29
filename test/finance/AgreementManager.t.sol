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

    function testFuzz_CreateAgreement_RevertWhen_UnsupportedScheme(uint256 amountSeed) public {
        address unsupportedArbiter = address(new AgreementManagerMockArbiter());
        uint256 amount = bound(amountSeed, 1e18, 100 * 1e18);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(AgreementManager.UnsupportedAgreementTarget.selector, unsupportedArbiter, token));
        IAgreementManager(agreementManager).createAgreement(amount, token, unsupportedArbiter, new address[](0), "");
    }

    function testFuzz_PreviewAgreement_MatchesPenalty(uint256 partiesLen) public {
        uint256 maxParties = IAgreementManagerExtended(agreementManager).maxParties();
        partiesLen = bound(partiesLen, 0, maxParties + 10);
        address[] memory parties = _buildParties(partiesLen);
        uint256 amount = 25 * 1e18;

        vm.prank(user);
        T.Agreement memory agreement = IAgreementManager(agreementManager).previewAgreement(amount, token, arbiter, parties, "");

        uint256 penalty = _penaltyBps(partiesLen, maxParties);
        uint256 expectedLocked = amount + ((amount * penalty) / C.BPS_MAX);
        assertEq(agreement.locked, expectedLocked, "Locked value should include penalty");
    }

    function testFuzz_CreateAgreement_MatchesPreview(uint256 amountSeed, uint8 partiesSeed) public {
        uint256 maxParties = IAgreementManagerExtended(agreementManager).maxParties();
        uint256 partiesLen = uint256(partiesSeed) % (maxParties + 6);
        address[] memory parties = _buildParties(partiesLen);
        uint256 available = ILedgerVerifiable(ledger).getLedgerBalance(user, token);
        uint256 penaltyBps = _penaltyBps(partiesLen, maxParties);

        uint256 maxAmount = available;
        if (penaltyBps > 0) {
            maxAmount = (available * C.BPS_MAX) / (C.BPS_MAX + penaltyBps);
        }
        if (maxAmount < 1e18) return;

        uint256 amount = bound(amountSeed, 1e18, maxAmount);
        bytes memory payload = abi.encode(amountSeed, partiesSeed);

        vm.prank(user);
        T.Agreement memory preview = IAgreementManager(agreementManager).previewAgreement(amount, token, arbiter, parties, payload);

        vm.startPrank(user);
        uint256 proof = IAgreementManager(agreementManager).createAgreement(amount, token, arbiter, parties, payload);
        vm.stopPrank();

        T.Agreement memory stored = IAgreementManager(agreementManager).getAgreement(proof);
        assertEq(stored.total, preview.total, "Total mismatch");
        assertEq(stored.fees, preview.fees, "Fees mismatch");
        assertEq(stored.locked, preview.locked, "Locked mismatch");
    }
}

contract AgreementManagerHandler is Test {
    struct AgreementInfo {
        bool exists;
        uint256 total;
        uint256 fees;
        uint256 locked;
    }

    IAgreementManagerExtended public immutable manager;
    ILedgerVerifiable public immutable vault;
    address public immutable token;
    address public immutable initiator;
    address public immutable arbiter;
    address public immutable admin;
    uint256 public immutable initialDeposit;

    uint256[] private _proofs;
    mapping(uint256 => AgreementInfo) private _agreements;
    uint256 private _totalLocked;
    uint256 private _nonce;

    constructor(
        address manager_,
        address vault_,
        address token_,
        address initiator_,
        address arbiter_,
        address admin_,
        uint256 initialDeposit_
    ) {
        manager = IAgreementManagerExtended(manager_);
        vault = ILedgerVerifiable(vault_);
        token = token_;
        initiator = initiator_;
        arbiter = arbiter_;
        admin = admin_;
        initialDeposit = initialDeposit_;
    }

    function createAgreement(uint256 amountSeed, uint8 partiesSeed) external {
        uint256 available = vault.getLedgerBalance(initiator, token);
        if (available < 1e18) return;

        uint256 maxParties = manager.maxParties();
        uint256 partiesLen = uint256(partiesSeed) % (maxParties + 6);
        uint256 penaltyBps = _penaltyBps(partiesLen, maxParties);
        if (penaltyBps > C.BPS_MAX) return;

        uint256 maxAmount = available;
        if (penaltyBps > 0) {
            maxAmount = (available * C.BPS_MAX) / (C.BPS_MAX + penaltyBps);
        }
        if (maxAmount < 1e18) return;

        uint256 amount = bound(amountSeed, 1e18, maxAmount);
        address[] memory parties = _buildParties(partiesLen);
        bytes memory payload = abi.encode(amountSeed, partiesSeed, _nonce++);

        vm.prank(initiator);
        uint256 proof = manager.createAgreement(amount, token, arbiter, parties, payload);

        if (_agreements[proof].exists) return;

        T.Agreement memory agreement = manager.getAgreement(proof);
        _agreements[proof] = AgreementInfo({ exists: true, total: agreement.total, fees: agreement.fees, locked: agreement.locked });
        _totalLocked += agreement.locked;
        _proofs.push(proof);
    }

    function setMaxParties(uint256 newMax) external {
        uint256 value = bound(newMax, 1, 10);
        vm.prank(admin);
        manager.setMaxParties(value);
    }

    function proofsLength() external view returns (uint256) {
        return _proofs.length;
    }

    function proofAt(uint256 index) external view returns (uint256) {
        return _proofs[index];
    }

    function info(uint256 proof) external view returns (AgreementInfo memory) {
        return _agreements[proof];
    }

    function totalLocked() external view returns (uint256) {
        return _totalLocked;
    }

    function recomputeLocked() external view returns (uint256 lockedSum) {
        uint256 len = _proofs.length;
        for (uint256 i = 0; i < len; i++) {
            AgreementInfo memory info = _agreements[_proofs[i]];
            if (!info.exists) continue;
            lockedSum += info.locked;
        }
    }

    function _buildParties(uint256 len) private view returns (address[] memory parties) {
        parties = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            parties[i] = vm.addr(500 + i);
        }
    }

    function _penaltyBps(uint256 partiesLen, uint256 maxParties) private pure returns (uint256) {
        if (partiesLen <= maxParties) return 0;
        uint256 excess = partiesLen - maxParties;
        return ((excess * (excess + 1)) / 2) * 100;
    }
}

contract AgreementManagerInvariantTest is BaseTest {
    AgreementManagerHandler handler;
    address internal arbiter;
    uint256 internal constant INITIAL_DEPOSIT = 5_000 * 1e18;

    function setUp() public initialize {
        deployAgreementManager();
        arbiter = address(new AgreementManagerMockArbiter());

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, arbiter, 400, token);

        vm.startPrank(admin);
        IERC20(token).approve(ledger, INITIAL_DEPOSIT);
        ILedgerVault(ledger).deposit(user, INITIAL_DEPOSIT, token);
        vm.stopPrank();

        handler = new AgreementManagerHandler(
            agreementManager,
            ledger,
            token,
            user,
            arbiter,
            admin,
            INITIAL_DEPOSIT
        );

        targetContract(address(handler));
    }

    function invariant_AgreementsStoredMatchHandler() external view {
        uint256 len = handler.proofsLength();
        for (uint256 i = 0; i < len; i++) {
            uint256 proof = handler.proofAt(i);
            AgreementManagerHandler.AgreementInfo memory info = handler.info(proof);
            if (!info.exists) continue;

            T.Agreement memory agreement = IAgreementManager(agreementManager).getAgreement(proof);
            assertEq(agreement.total, info.total, "Total mismatch");
            assertEq(agreement.fees, info.fees, "Fees mismatch");
            assertEq(agreement.locked, info.locked, "Locked mismatch");
            assertEq(agreement.arbiter, arbiter, "Arbiter mismatch");
            assertEq(agreement.initiator, user, "Initiator mismatch");
        }
    }

    function invariant_UserLedgerPlusLockedEqualsInitial() external view {
        uint256 ledgerBalance = ILedgerVerifiable(ledger).getLedgerBalance(user, token);
        assertEq(ledgerBalance + handler.totalLocked(), INITIAL_DEPOSIT, "Ledger accounting mismatch");
    }

    function invariant_LockedTotalsConsistent() external view {
        assertEq(handler.totalLocked(), handler.recomputeLocked(), "Tracked locked total mismatch");
    }
}
