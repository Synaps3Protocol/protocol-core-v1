// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AgreementSettler } from "contracts/financial/AgreementSettler.sol";
import { RightsPolicyManager } from "contracts/rights/RightsPolicyManager.sol";
import { PolicyBase } from "contracts/policies/PolicyBase.sol";

import { BaseTest } from "test/BaseTest.t.sol";
import { IRightsPolicyAuthorizer } from "contracts/core/interfaces/rights/IRightsPolicyAuthorizer.sol";
import { IAgreementManager } from "contracts/core/interfaces/financial/IAgreementManager.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { ILedgerVault } from "contracts/core/interfaces/financial/ILedgerVault.sol";
import { IPolicyAuditor } from "contracts/core/interfaces/policies/IPolicyAuditor.sol";
import { IAttestationProvider } from "contracts/core/interfaces/base/IAttestationProvider.sol";
import { T } from "contracts/core/primitives/Types.sol";

uint256 constant DEFAULT_TOLLGATE_BPS = 500;
uint256 constant DEFAULT_AGREEMENT_AMOUNT = 100 ether;
uint256 constant INITIAL_LEDGER_DEPOSIT = 1_000_000 ether;
bytes constant DEFAULT_PAYLOAD = "payload";

/// @dev Attestation provider stub allowing configurable attestation ids.
contract ConfigurableAttestationProvider is IAttestationProvider {
    address[] internal _lastRecipients;
    uint256 public lastExpireAt;
    bytes public lastData;
    uint256 public attestCalls;

    uint256[] internal _nextIds;
    uint256 private _counter = 1;
    mapping(address => mapping(uint256 => bool)) internal _issued;

    function setNextAttestationIds(uint256[] memory ids) external {
        delete _nextIds;
        uint256 len = ids.length;
        for (uint256 i = 0; i < len; i++) {
            _nextIds.push(ids[i]);
        }
    }

    function getName() external pure returns (string memory) {
        return "ConfigurableAttestationProvider";
    }

    function getAddress() external view returns (address) {
        return address(this);
    }

    function attest(
        address[] calldata recipients,
        uint256 expireAt,
        bytes calldata data
    ) external override returns (uint256[] memory attestationIds) {
        delete _lastRecipients;
        uint256 len = recipients.length;
        for (uint256 i = 0; i < len; i++) {
            _lastRecipients.push(recipients[i]);
        }

        lastExpireAt = expireAt;
        lastData = data;
        attestCalls++;

        attestationIds = new uint256[](len);
        if (len == 0) return attestationIds;

        if (_nextIds.length != 0) {
            require(_nextIds.length == len, "Attestation length mismatch");
            for (uint256 i = 0; i < len; i++) {
                attestationIds[i] = _nextIds[i];
            }
            delete _nextIds;
        } else {
            for (uint256 i = 0; i < len; i++) {
                attestationIds[i] = _counter++;
            }
        }

        for (uint256 i = 0; i < len; i++) {
            _issued[recipients[i]][attestationIds[i]] = true;
        }
        return attestationIds;
    }

    function verify(uint256 attestationId, address recipient) external view returns (bool) {
        return _issued[recipient][attestationId];
    }

    function lastRecipientsLength() external view returns (uint256) {
        return _lastRecipients.length;
    }

    function lastRecipientAt(uint256 index) external view returns (address) {
        return _lastRecipients[index];
    }
}

/// @dev Policy harness leveraging PolicyBase for realistic behaviour.
contract PolicyBaseManagerHarness is PolicyBase {
    address private _lastHolder;
    bytes private _lastSetupData;
    T.Agreement private _lastAgreement;

    bool public setupShouldRevert;
    bool public enforceShouldRevert;
    bool public accessAllowed = true;
    bool public accessShouldRevert;

    constructor(
        address rightsPolicyManager,
        address rightsAuthorizer,
        address assetRegistry,
        address attestationProvider
    ) PolicyBase(rightsPolicyManager, rightsAuthorizer, assetRegistry, attestationProvider) {}

    function setSetupRevert(bool status) external {
        setupShouldRevert = status;
    }

    function setAccessAllowed(bool status) external {
        accessAllowed = status;
    }

    function setAccessRevert(bool status) external {
        accessShouldRevert = status;
    }

    function setEnforceRevert(bool status) external {
        enforceShouldRevert = status;
    }

    function lastHolder() external view returns (address) {
        return _lastHolder;
    }

    function lastSetupData() external view returns (bytes memory) {
        return _lastSetupData;
    }

    function getLastAgreement() external view returns (T.Agreement memory) {
        return _lastAgreement;
    }

    function setup(address holder, bytes calldata init) external override {
        if (setupShouldRevert) revert("policy setup failed");
        _lastHolder = holder;
        _lastSetupData = init;
    }

    function enforce(
        address holder,
        T.Agreement calldata agreement
    ) external override returns (uint256[] memory attestationIds) {
        if (enforceShouldRevert) revert("enforce failure");
        _lastHolder = holder;
        _lastAgreement = agreement;

        uint256 expireAt = block.timestamp + 1;
        attestationIds = _commit(holder, agreement, expireAt);

        uint256 len = agreement.parties.length;
        bytes memory context = abi.encode(holder);
        for (uint256 i = 0; i < len; i++) {
            _setAttestation(agreement.parties[i], context, attestationIds[i]);
        }
    }

    function isAccessAllowed(address, bytes calldata) external view override returns (bool) {
        if (accessShouldRevert) revert("access check failed");
        return accessAllowed;
    }

    function resolveTerms(bytes calldata) external pure override returns (T.Terms memory terms) {}

    function name() external pure override returns (string memory) {
        return "PolicyBaseManagerHarness";
    }

    function description() external pure override returns (string memory) {
        return "Policy base test harness";
    }
}

contract RightsPolicyManagerTest is BaseTest {
    RightsPolicyManager internal manager;
    IRightsPolicyAuthorizer internal authorizer;
    IAgreementManager internal agreements;
    IPolicyAuditor internal auditor;
    ITollgate internal tollgateContract;
    ILedgerVault internal ledgerVault;
    IERC20 internal currency;

    address internal holder;

    mapping(address => bool) internal auditedPolicies;
    mapping(address => bool) internal authorizedPolicies;

    event Registered(address indexed account, uint256 indexed proof, uint256 attestationId, address policy);

    function setUp() public initialize {
        holder = user;

        deployRightsPolicyManager();

        manager = RightsPolicyManager(rightsPolicyManager);
        authorizer = IRightsPolicyAuthorizer(rightsPolicyAuthorizer);
        agreements = IAgreementManager(agreementManager);
        auditor = IPolicyAuditor(policyAudit);
        tollgateContract = ITollgate(tollgate);
        ledgerVault = ILedgerVault(ledger);
        currency = IERC20(token);

        _configureTollgate();
        _seedLedgerBalance(holder, INITIAL_LEDGER_DEPOSIT);
    }

    function _configureTollgate() internal {
        vm.prank(governor);
        tollgateContract.setFees(T.Scheme.BPS, address(manager), DEFAULT_TOLLGATE_BPS, address(currency));
    }

    function _seedLedgerBalance(address account, uint256 amount) internal {
        vm.startPrank(governor);
        currency.approve(address(ledgerVault), amount);
        ledgerVault.deposit(account, amount, address(currency));
        vm.stopPrank();
    }

    function _deployPolicy()
        internal
        returns (PolicyBaseManagerHarness policy, ConfigurableAttestationProvider provider)
    {
        provider = new ConfigurableAttestationProvider();
        policy = new PolicyBaseManagerHarness(address(manager), address(authorizer), assetRegistry, address(provider));
    }

    function _authorizePolicy(PolicyBaseManagerHarness policy, bytes memory data) internal {
        _auditPolicy(address(policy));
        if (authorizedPolicies[address(policy)]) return;

        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), data);
        authorizedPolicies[address(policy)] = true;
    }

    function _auditPolicy(address policy) internal {
        if (auditedPolicies[policy]) return;

        vm.prank(holder);
        try auditor.submit(policy) {} catch {}

        vm.prank(admin);
        try auditor.approve(policy) {
            auditedPolicies[policy] = true;
        } catch {}

        if (!auditedPolicies[policy] && auditor.isApproved(policy)) {
            auditedPolicies[policy] = true;
        }
    }

    function _createAgreement(
        address[] memory parties
    ) internal returns (uint256 proof, T.Agreement memory agreement) {
        vm.roll(block.number + 1);
        vm.startPrank(holder);
        proof = agreements.createAgreement(
            DEFAULT_AGREEMENT_AMOUNT,
            address(currency),
            address(manager),
            parties,
            DEFAULT_PAYLOAD
        );
        vm.stopPrank();
        agreement = agreements.getAgreement(proof);
    }

    function _createAgreementWithArbiter(
        address arbiter,
        address[] memory parties
    ) internal returns (uint256 proof, T.Agreement memory agreement) {
        vm.roll(block.number + 1);
        vm.prank(governor);
        tollgateContract.setFees(T.Scheme.BPS, arbiter, DEFAULT_TOLLGATE_BPS, address(currency));

        vm.startPrank(holder);
        proof = agreements.createAgreement(DEFAULT_AGREEMENT_AMOUNT, address(currency), arbiter, parties, DEFAULT_PAYLOAD);
        vm.stopPrank();
        agreement = agreements.getAgreement(proof);
    }

    function _collectedFees(T.Agreement memory agreement) internal pure returns (uint256) {
        return agreement.fees + (agreement.locked - agreement.total);
    }

    function test_RegisterPolicy_SucceedsForAuthorizedPolicy() public {
        (PolicyBaseManagerHarness policy, ConfigurableAttestationProvider provider) = _deployPolicy();
        _authorizePolicy(policy, abi.encode(uint256(1)));

        address[] memory parties = new address[](2);
        parties[0] = vm.addr(11);
        parties[1] = vm.addr(12);
        (uint256 proof, T.Agreement memory agreement) = _createAgreement(parties);

        uint256[] memory attestationIds = new uint256[](2);
        attestationIds[0] = 777;
        attestationIds[1] = 888;
        provider.setNextAttestationIds(attestationIds);

        vm.expectEmit(true, true, true, true, agreementSettler);
        emit AgreementSettler.AgreementSettled(address(manager), holder, proof, _collectedFees(agreement));

        vm.expectEmit(true, true, true, true);
        emit Registered(parties[0], proof, attestationIds[0], address(policy));
        vm.expectEmit(true, true, true, true);
        emit Registered(parties[1], proof, attestationIds[1], address(policy));

        uint256[] memory result = manager.registerPolicy(proof, holder, address(policy));
        assertEq(result.length, attestationIds.length, "Unexpected attestation array length");
        for (uint256 i = 0; i < result.length; i++) {
            assertEq(result[i], attestationIds[i], "Attestation id mismatch");
        }

        assertEq(policy.lastHolder(), holder, "Holder mismatch recorded in policy");
        address retrievedArbiter;
        address[] memory enforcedParties;
        bytes memory payload;
        T.Agreement memory enforced = policy.getLastAgreement();
        retrievedArbiter = enforced.arbiter;
        enforcedParties = enforced.parties;
        payload = enforced.payload;
        assertEq(retrievedArbiter, agreement.arbiter, "Stored agreement arbiter mismatch");
        assertEq(enforcedParties.length, agreement.parties.length, "Stored agreement parties mismatch");

        address[] memory holderPolicies = manager.getPolicies(parties[0]);
        assertEq(holderPolicies.length, 1, "First party should have one policy");
        assertEq(holderPolicies[0], address(policy), "Unexpected policy stored for first party");

        holderPolicies = manager.getPolicies(parties[1]);
        assertEq(holderPolicies.length, 1, "Second party should have one policy");
        assertEq(holderPolicies[0], address(policy), "Unexpected policy stored for second party");
    }

    function test_RegisterPolicy_RevertsWhenPolicyNotAuthorized() public {
        (PolicyBaseManagerHarness policy, ) = _deployPolicy();

        address[] memory parties = new address[](1);
        parties[0] = vm.addr(101);
        (uint256 proof, ) = _createAgreement(parties);

        vm.expectRevert(abi.encodeWithSelector(RightsPolicyManager.RightsNotDelegated.selector, address(policy), holder));
        manager.registerPolicy(proof, holder, address(policy));
    }

    function test_RegisterPolicy_RevertsWhenAgreementHasNoParties() public {
        (PolicyBaseManagerHarness policy, ) = _deployPolicy();
        _authorizePolicy(policy, "");

        address[] memory parties = new address[](0);
        (uint256 proof, ) = _createAgreement(parties);

        vm.expectRevert(
            abi.encodeWithSelector(
                RightsPolicyManager.EnforcementFailed.selector,
                "No parties in agreement: at least one party is required."
            )
        );
        manager.registerPolicy(proof, holder, address(policy));
    }

    function test_RegisterPolicy_RevertsWhenEnforceFails() public {
        (PolicyBaseManagerHarness policy, ) = _deployPolicy();
        policy.setEnforceRevert(true);
        _authorizePolicy(policy, "");

        address[] memory parties = new address[](1);
        parties[0] = vm.addr(99);
        (uint256 proof, ) = _createAgreement(parties);

        vm.expectRevert(
            abi.encodeWithSelector(
                RightsPolicyManager.EnforcementFailed.selector,
                "Error during policy enforcement call"
            )
        );
        manager.registerPolicy(proof, holder, address(policy));
    }

    function test_RegisterPolicy_RevertsWhenSettlerFails() public {
        (PolicyBaseManagerHarness policy, ) = _deployPolicy();
        _authorizePolicy(policy, "");

        address[] memory parties = new address[](1);
        parties[0] = vm.addr(77);
        (uint256 proof, ) = _createAgreementWithArbiter(address(this), parties);

        vm.expectRevert(AgreementSettler.UnauthorizedEscrowAgent.selector);
        manager.registerPolicy(proof, holder, address(policy));
    }

    function test_GetActivePolicy_ReturnsFirstMatchingPolicy() public {
        address account = vm.addr(222);
        address[] memory parties = new address[](1);
        parties[0] = account;

        (PolicyBaseManagerHarness inactivePolicy, ConfigurableAttestationProvider inactiveProvider) = _deployPolicy();
        inactivePolicy.setAccessAllowed(false);
        _authorizePolicy(inactivePolicy, "");
        inactiveProvider.setNextAttestationIds(_singleAttestation(1));
        (uint256 inactiveProof, ) = _createAgreement(parties);
        manager.registerPolicy(inactiveProof, holder, address(inactivePolicy));

        (PolicyBaseManagerHarness activePolicy, ConfigurableAttestationProvider activeProvider) = _deployPolicy();
        activePolicy.setAccessAllowed(true);
        _authorizePolicy(activePolicy, "");
        activeProvider.setNextAttestationIds(_singleAttestation(2));
        (uint256 activeProof, ) = _createAgreement(parties);
        manager.registerPolicy(activeProof, holder, address(activePolicy));

        (bool found, address policyAddress) = manager.getActivePolicy(account, abi.encode("criteria"));
        assertTrue(found, "An active policy should be found");
        assertEq(policyAddress, address(activePolicy), "Expected the active policy to be returned");
    }

    function test_GetActivePolicies_FiltersInactiveOnes() public {
        address account = vm.addr(333);
        address[] memory parties = new address[](1);
        parties[0] = account;

        (PolicyBaseManagerHarness policyA, ConfigurableAttestationProvider providerA) = _deployPolicy();
        policyA.setAccessAllowed(true);
        _authorizePolicy(policyA, "");
        providerA.setNextAttestationIds(_singleAttestation(101));
        (uint256 proofA, ) = _createAgreement(parties);
        manager.registerPolicy(proofA, holder, address(policyA));

        (PolicyBaseManagerHarness policyB, ConfigurableAttestationProvider providerB) = _deployPolicy();
        policyB.setAccessAllowed(false);
        _authorizePolicy(policyB, "");
        providerB.setNextAttestationIds(_singleAttestation(102));
        (uint256 proofB, ) = _createAgreement(parties);
        manager.registerPolicy(proofB, holder, address(policyB));

        (PolicyBaseManagerHarness policyC, ConfigurableAttestationProvider providerC) = _deployPolicy();
        policyC.setAccessAllowed(true);
        _authorizePolicy(policyC, "");
        providerC.setNextAttestationIds(_singleAttestation(103));
        (uint256 proofC, ) = _createAgreement(parties);
        manager.registerPolicy(proofC, holder, address(policyC));

        address[] memory activePolicies = manager.getActivePolicies(account, "");
        assertEq(activePolicies.length, 2, "Only active policies should be returned");
        assertEq(activePolicies[0], address(policyA), "First active policy mismatch");
        assertEq(activePolicies[1], address(policyC), "Second active policy mismatch");
    }

    function test_IsActivePolicy_ReturnsFalseWhenAccessCheckReverts() public {
        (PolicyBaseManagerHarness policy, ConfigurableAttestationProvider provider) = _deployPolicy();
        _authorizePolicy(policy, "");
        policy.setAccessRevert(true);

        address[] memory parties = new address[](1);
        parties[0] = vm.addr(404);
        provider.setNextAttestationIds(_singleAttestation(9));

        assertFalse(manager.isActivePolicy(parties[0], address(policy), ""), "Unknown policy should be inactive");

        (uint256 proof, ) = _createAgreement(parties);
        manager.registerPolicy(proof, holder, address(policy));

        assertFalse(manager.isActivePolicy(parties[0], address(policy), ""), "Reverting policy should be treated as inactive");
    }

    function testFuzz_RegisterPolicy_StoresPolicyOnce(
        address account,
        uint256 proofSeed,
        uint256 attestation
    ) public {
        vm.assume(account != address(0));

        (PolicyBaseManagerHarness policy, ConfigurableAttestationProvider provider) = _deployPolicy();
        _authorizePolicy(policy, abi.encode(proofSeed));

        address[] memory parties = new address[](1);
        parties[0] = account;

        uint8 repeats = uint8(bound(proofSeed, 1, 3));
        uint256 baseAttestation = bound(attestation, 1, type(uint256).max - repeats);
        for (uint8 i = 0; i < repeats; i++) {
            provider.setNextAttestationIds(_singleAttestation(baseAttestation + i));
            (uint256 proof, ) = _createAgreement(parties);
            manager.registerPolicy(proof, holder, address(policy));
        }

        address[] memory policies = manager.getPolicies(account);
        assertEq(policies.length, 1, "Policy should be registered once");
        assertEq(policies[0], address(policy), "Stored policy mismatch");
    }

    function _singleAttestation(uint256 value) internal pure returns (uint256[] memory attestationIds) {
        attestationIds = new uint256[](1);
        attestationIds[0] = value;
    }
}
