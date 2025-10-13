// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { PolicyBase } from "contracts/policies/PolicyBase.sol";
import { IPolicy } from "contracts/core/interfaces/policies/IPolicy.sol";
import { IAttestationProvider } from "contracts/core/interfaces/base/IAttestationProvider.sol";
import { IAssetRegistry } from "contracts/core/interfaces/assets/IAssetRegistry.sol";
import { IRightsPolicyManagerVerifiable } from "contracts/core/interfaces/rights/IRightsPolicyManagerVerifiable.sol";
import { IRightsPolicyAuthorizerVerifiable } from "contracts/core/interfaces/rights/IRightsPolicyAuthorizerVerifiable.sol";
import { T } from "contracts/core/primitives/Types.sol";

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract RightsPolicyManagerVerifiableMock is IRightsPolicyManagerVerifiable {
    function getPolicies(address) external pure override returns (address[] memory policies) {
        policies = new address[](0);
    }

    function getActivePolicy(address, bytes memory) external pure override returns (bool active, address policyAddress) {
        return (false, address(0));
    }

    function getActivePolicies(address, bytes memory) external pure override returns (address[] memory policies) {
        policies = new address[](0);
    }

    function isActivePolicy(address, address, bytes calldata) external pure override returns (bool) {
        return false;
    }

    function isRegisteredPolicy(address, address) external pure override returns (bool) {
        return false;
    }
}

contract RightsPolicyAuthorizerVerifiableMock is IRightsPolicyAuthorizerVerifiable {
    function getAuthorizedPolicies(address) external pure override returns (address[] memory policies) {
        policies = new address[](0);
    }

    function isPolicyAuthorized(address, address) external pure override returns (bool) {
        return false;
    }
}

contract AttestationProviderMock is IAttestationProvider {
    address[] internal _lastRecipients;
    uint256 public lastExpireAt;
    bytes public lastData;
    uint256 public attestCalls;
    uint256 private _nextId = 1;
    mapping(address => mapping(uint256 => bool)) internal _issued;

    function getName() external pure returns (string memory) {
        return "mock";
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
        for (uint256 i = 0; i < len; i++) {
            uint256 id = _nextId++;
            attestationIds[i] = id;
            _issued[recipients[i]][id] = true;
        }
        if (len == 0) {
            _nextId++;
        }
    }

    function lastRecipientsLength() external view returns (uint256) {
        return _lastRecipients.length;
    }

    function lastRecipientAt(uint256 index) external view returns (address) {
        return _lastRecipients[index];
    }

    function verify(uint256 attestationId, address recipient) external view returns (bool) {
        return _issued[recipient][attestationId];
    }
}

contract AssetRegistryMock is ERC721, IAssetRegistry {
    constructor() ERC721("MockRegistry", "MREG") {}

    function register(address to, uint256 assetId) external override {
        _mint(to, assetId);
    }

    function revoke(uint256 assetId) external override {
        _burn(assetId);
    }

    function transfer(address to, uint256 assetId) external override {
        safeTransferFrom(msg.sender, to, assetId);
    }
}

contract PolicyBaseHarness is PolicyBase {
    constructor(
        address rightsPolicyManager,
        address rightsAuthorizer,
        address assetRegistry,
        address attestationProvider
    ) PolicyBase(rightsPolicyManager, rightsAuthorizer, assetRegistry, attestationProvider) {}

    function managerPing() external onlyPolicyManager returns (bool) {
        return true;
    }

    function authorizerPing() external onlyPolicyAuthorizer returns (bool) {
        return true;
    }

    function exposeCommit(
        address holder,
        T.Agreement calldata agreement,
        uint256 expireAt
    ) external returns (uint256[] memory) {
        return _commit(holder, agreement, expireAt);
    }

    function exposeSetAttestation(address account, bytes memory context, uint256 attestationId) external {
        _setAttestation(account, context, attestationId);
    }

    function exposeHolder(uint256 assetId) external view returns (address) {
        return _getHolder(assetId);
    }

    function setup(address, bytes calldata) external pure override {}

    function enforce(
        address,
        T.Agreement calldata agreement
    ) external pure override returns (uint256[] memory result) {
        result = new uint256[](agreement.parties.length);
    }

    function isAccessAllowed(address, bytes calldata) external pure override returns (bool) {
        return true;
    }

    function resolveTerms(bytes calldata) external pure override returns (T.Terms memory terms) {}

    function name() external pure override returns (string memory) {
        return "PolicyBaseHarness";
    }

    function description() external pure override returns (string memory) {
        return "Policy base test harness";
    }
}

contract PolicyBaseTest is Test {
    RightsPolicyManagerVerifiableMock internal manager;
    RightsPolicyAuthorizerVerifiableMock internal authorizer;
    AssetRegistryMock internal registry;
    AttestationProviderMock internal attestation;
    PolicyBaseHarness internal policy;

    address internal holder = address(0xBEEF);
    address internal keeper = address(0xCAFE);

    function setUp() public {
        manager = new RightsPolicyManagerVerifiableMock();
        authorizer = new RightsPolicyAuthorizerVerifiableMock();
        registry = new AssetRegistryMock();
        attestation = new AttestationProviderMock();
        policy = new PolicyBaseHarness(address(manager), address(authorizer), address(registry), address(attestation));
    }

    function test_GetAttestationProvider_ReturnsConfiguredAddress() public {
        assertEq(policy.getAttestationProvider(), address(attestation), "Unexpected attestation provider address");
    }

    function test_SupportsInterface_ForIPolicy() public {
        assertTrue(policy.supportsInterface(type(IPolicy).interfaceId), "IPolicy interface support missing");
        assertFalse(policy.supportsInterface(bytes4(0xdeadbeef)), "Unexpected interface should be unsupported");
    }

    function test_OnlyPolicyManager_AllowsManagerAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(PolicyBase.InvalidUnauthorizedCall.selector, "Only rights policy manager allowed.")
        );
        policy.managerPing();

        vm.prank(address(manager));
        assertTrue(policy.managerPing(), "Manager call should succeed");
    }

    function test_OnlyPolicyAuthorizer_AllowsAuthorizerAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(PolicyBase.InvalidUnauthorizedCall.selector, "Only rights policy authorizer allowed.")
        );
        policy.authorizerPing();

        vm.prank(address(authorizer));
        assertTrue(policy.authorizerPing(), "Authorizer call should succeed");
    }

    function test_SetAttestationStoresAndEmits() public {
        address account = address(0xA11CE);
        bytes memory context = abi.encodePacked(uint256(1));
        uint256 attestationId = 321;
        bytes32 composedKey = keccak256(abi.encodePacked(account, context));

        vm.expectEmit(true, true, true, true);
        emit PolicyBase.AttestedAgreement(composedKey, account, attestationId);

        policy.exposeSetAttestation(account, context, attestationId);
        assertEq(policy.getLicense(account, context), attestationId, "Stored attestation mismatch");
    }

    function test_CommitCreatesAttestations() public {
        address[] memory parties = new address[](2);
        parties[0] = holder;
        parties[1] = keeper;

        T.Agreement memory agreement = T.Agreement({
            arbiter: address(0xAB),
            currency: address(0xCD),
            initiator: address(0xEF),
            total: 1_000,
            fees: 100,
            locked: 900,
            parties: parties,
            payload: abi.encode("payload")
        });

        uint256 expireAt = block.timestamp + 1 days;

        vm.expectEmit(true, false, false, true);
        emit PolicyBase.AgreementCommitted(holder, parties.length, agreement.total, agreement.fees);

        uint256[] memory attestationIds = policy.exposeCommit(holder, agreement, expireAt);

        assertEq(attestationIds.length, parties.length, "Attestation length mismatch");
        assertEq(attestationIds[0], 1, "First attestation id mismatch");
        assertEq(attestationIds[1], 2, "Second attestation id mismatch");
        assertEq(attestation.attestCalls(), 1, "Attest should be invoked once");
        assertEq(attestation.lastExpireAt(), expireAt, "Expire timestamp mismatch");
        assertEq(attestation.lastRecipientsLength(), parties.length, "Recipients length mismatch");
        assertEq(attestation.lastRecipientAt(0), holder, "First recipient mismatch");
        assertEq(attestation.lastRecipientAt(1), keeper, "Second recipient mismatch");
    }

    function test_GetHolderReadsFromRegistry() public {
        uint256 assetId = 42;
        registry.register(holder, assetId);
        assertEq(policy.exposeHolder(assetId), holder, "Holder should come from registry");
    }
}
