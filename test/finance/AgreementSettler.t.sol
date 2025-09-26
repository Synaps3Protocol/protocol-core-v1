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

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, address(arbiter), 500, token);

        vm.startPrank(admin);
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

        vm.expectRevert(AgreementSettler.AgreementAlreadySettled.selector);
        vm.prank(user);
        IAgreementSettlerExtended(agreementSettler).quitAgreement(proof);
    }

    function test_QuitAgreement_RevertWhen_NotInitiator() public {
        uint256 amount = 30 * 1e18;
        (uint256 proof, ) = _createAgreement(amount, 1);

        vm.expectRevert(AgreementSettler.UnauthorizedInitiator.selector);
        vm.prank(vm.addr(3333));
        IAgreementSettlerExtended(agreementSettler).quitAgreement(proof);
    }

    function testFuzz_SettleAgreement_LedgerConsistency(uint256 amountSeed, uint8 partiesSeed) public {
        uint256 partiesLen = uint256(partiesSeed) % (IAgreementManagerExtended(agreementManager).maxParties() + 5);
        uint256 amount = _boundedAmount(amountSeed, partiesLen);
        if (amount == 0) return;

        (uint256 proof, ) = _createAgreement(amount, partiesLen);
        address counterparty = vm.addr(9000 + partiesLen);
        vm.prank(address(arbiter));
        T.Agreement memory settled = IAgreementSettlerExtended(agreementSettler).settleAgreement(proof, counterparty);

        uint256 available = settled.total - settled.fees;
        uint256 protocolTake = settled.fees + (settled.locked - settled.total);

        assertEq(ILedgerVerifiable(ledger).getLedgerBalance(counterparty, token), available, "Counterparty ledger mismatch");
        assertEq(ILedgerVerifiable(ledger).getLedgerBalance(agreementSettler, token), protocolTake, "Settler ledger mismatch");
    }

    function testFuzz_QuitAgreement_LedgerConsistency(uint256 amountSeed, uint8 partiesSeed) public {
        uint256 partiesLen = uint256(partiesSeed) % (IAgreementManagerExtended(agreementManager).maxParties() + 5);
        uint256 amount = _boundedAmount(amountSeed, partiesLen);
        if (amount == 0) return;

        (uint256 proof, T.Agreement memory agreement) = _createAgreement(amount, partiesLen);
        uint256 protocolTake = agreement.fees + (agreement.locked - agreement.total);

        vm.prank(user);
        IAgreementSettlerExtended(agreementSettler).quitAgreement(proof);

        assertEq(ILedgerVerifiable(ledger).getLedgerBalance(agreementSettler, token), protocolTake, "Protocol take ledger mismatch");
        assertEq(
            ILedgerVerifiable(ledger).getLedgerBalance(user, token),
            INITIAL_DEPOSIT - protocolTake,
            "User ledger mismatch after quit"
        );
    }
}

contract AgreementSettlerHandler is Test {
    IAgreementSettlerExtended public immutable settler;
    IAgreementManagerExtended public immutable manager;
    ILedgerVerifiable public immutable vault;
    address public immutable token;
    address public immutable initiator;
    SettlerMockArbiter public immutable arbiter;

    struct ProofState {
        bool exists;
        bool settled;
        bool cancelled;
        uint256 total;
        uint256 fees;
        uint256 locked;
        uint256 protocolTake;
        uint256 available;
    }

    uint256[] private _proofs;
    mapping(uint256 => ProofState) private _states;
    uint256 private _activeLocked;
    uint256 private _protocolTake;
    uint256 private _payout;
    uint256 private _nonce;

    constructor(
        address settler_,
        address manager_,
        address vault_,
        address token_,
        address initiator_,
        address arbiter_
    ) {
        settler = IAgreementSettlerExtended(settler_);
        manager = IAgreementManagerExtended(manager_);
        vault = ILedgerVerifiable(vault_);
        token = token_;
        initiator = initiator_;
        arbiter = SettlerMockArbiter(arbiter_);
    }

    function createAgreement(uint256 amountSeed, uint8 partiesSeed) external {
        uint256 partiesLen = uint256(partiesSeed) % (manager.maxParties() + 5);
        uint256 penaltyBps = _penaltyBps(partiesLen, manager.maxParties());
        uint256 available = vault.getLedgerBalance(initiator, token);
        if (available < 1e18) return;

        uint256 maxAmount = available;
        if (penaltyBps > 0) {
            maxAmount = (available * C.BPS_MAX) / (C.BPS_MAX + penaltyBps);
        }
        if (maxAmount < 1e18) return;

        uint256 amount = bound(amountSeed, 1e18, maxAmount);
        address[] memory parties = _buildParties(partiesLen);
        bytes memory payload = abi.encode(_nonce++);
        vm.prank(initiator);
        uint256 proof = manager.createAgreement(amount, token, address(arbiter), parties, payload);
        if (_states[proof].exists) return;

        T.Agreement memory agreement = manager.getAgreement(proof);
        _states[proof] = ProofState({
            exists: true,
            settled: false,
            cancelled: false,
            total: agreement.total,
            fees: agreement.fees,
            locked: agreement.locked,
            protocolTake: 0,
            available: agreement.total - agreement.fees
        });
        _activeLocked += agreement.locked;
        _proofs.push(proof);
    }

    function settle(uint256 proofSeed, address counterpartySeed) external {
        if (_proofs.length == 0) return;
        uint256 proof = _proofs[proofSeed % _proofs.length];
        ProofState storage state = _states[proof];
        if (!state.exists || state.settled || state.cancelled) return;

        address counterParty = counterpartySeed;
        while (counterParty == address(0) || counterParty == initiator || counterParty == address(settler)) {
            counterParty = vm.addr(uint256(uint160(counterParty)) + 1);
        }

        vm.prank(address(arbiter));
        T.Agreement memory settled = settler.settleAgreement(proof, counterParty);
        uint256 protocolTake = settled.fees + (settled.locked - settled.total);
        uint256 available = settled.total - settled.fees;

        state.settled = true;
        state.protocolTake = protocolTake;
        state.available = available;

        _activeLocked -= settled.locked;
        _protocolTake += protocolTake;
        _payout += available;
    }

    function quit(uint256 proofSeed) external {
        if (_proofs.length == 0) return;
        uint256 proof = _proofs[proofSeed % _proofs.length];
        ProofState storage state = _states[proof];
        if (!state.exists || state.settled || state.cancelled) return;

        vm.prank(initiator);
        T.Agreement memory cancelled = settler.quitAgreement(proof);
        uint256 protocolTake = cancelled.fees + (cancelled.locked - cancelled.total);

        state.cancelled = true;
        state.protocolTake = protocolTake;

        _activeLocked -= cancelled.locked;
        _protocolTake += protocolTake;
    }

    function proofsLength() external view returns (uint256) {
        return _proofs.length;
    }

    function proofAt(uint256 index) external view returns (uint256) {
        return _proofs[index];
    }

    function stateOf(uint256 proof) external view returns (ProofState memory) {
        return _states[proof];
    }

    function activeLocked() external view returns (uint256) {
        return _activeLocked;
    }

    function totalProtocolTake() external view returns (uint256) {
        return _protocolTake;
    }

    function totalPayout() external view returns (uint256) {
        return _payout;
    }

    function recomputeActiveLocked() external view returns (uint256 sum) {
        uint256 len = _proofs.length;
        for (uint256 i = 0; i < len; i++) {
            ProofState memory state = _states[_proofs[i]];
            if (!state.exists || state.settled || state.cancelled) continue;
            sum += state.locked;
        }
    }

    function _buildParties(uint256 len) private view returns (address[] memory parties) {
        parties = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            parties[i] = vm.addr(1_500 + i);
        }
    }

    function _penaltyBps(uint256 partiesLen, uint256 maxParties) private pure returns (uint256) {
        if (partiesLen <= maxParties) return 0;
        uint256 excess = partiesLen - maxParties;
        return ((excess * (excess + 1)) / 2) * 100;
    }
}

contract AgreementSettlerInvariantTest is BaseTest {
    AgreementSettlerHandler handler;
    SettlerMockArbiter arbiter;
    uint256 internal constant INITIAL_DEPOSIT = 8_000 * 1e18;

    function setUp() public initialize {
        deployAgreementSettler();
        arbiter = new SettlerMockArbiter(agreementSettler);

        vm.prank(governor);
        ITollgate(tollgate).setFees(T.Scheme.BPS, address(arbiter), 350, token);

        vm.startPrank(admin);
        IERC20(token).approve(ledger, INITIAL_DEPOSIT);
        ILedgerVault(ledger).deposit(user, INITIAL_DEPOSIT, token);
        vm.stopPrank();

        handler = new AgreementSettlerHandler(
            agreementSettler,
            agreementManager,
            ledger,
            token,
            user,
            address(arbiter)
        );

        targetContract(address(handler));
    }

    function invariant_SettlerLedgerMatchesProtocolTake() external view {
        uint256 settlerLedger = ILedgerVerifiable(ledger).getLedgerBalance(agreementSettler, token);
        assertEq(settlerLedger, handler.totalProtocolTake(), "Settler ledger mismatch");
    }

    function invariant_UserLedgerAccountingHolds() external view {
        uint256 userLedger = ILedgerVerifiable(ledger).getLedgerBalance(user, token);
        uint256 total = userLedger + handler.activeLocked() + handler.totalProtocolTake() + handler.totalPayout();
        assertEq(total, INITIAL_DEPOSIT, "Ledger accounting must balance");
    }

    function invariant_ActiveLockedConsistency() external view {
        assertEq(handler.activeLocked(), handler.recomputeActiveLocked(), "Active locked tracking mismatch");
    }

    function invariant_AgreementStateMatchesManager() external view {
        uint256 len = handler.proofsLength();
        for (uint256 i = 0; i < len; i++) {
            uint256 proof = handler.proofAt(i);
            AgreementSettlerHandler.ProofState memory state = handler.stateOf(proof);
            if (!state.exists) continue;

            T.Agreement memory agreement = IAgreementManager(agreementManager).getAgreement(proof);
            assertEq(agreement.total, state.total, "Agreement total mismatch");
            assertEq(agreement.fees, state.fees, "Agreement fees mismatch");
            assertEq(agreement.locked, state.locked, "Agreement locked mismatch");
            assertEq(agreement.arbiter, address(arbiter), "Arbiter mismatch");
            assertEq(agreement.initiator, user, "Initiator mismatch");
        }
    }
}
