// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { RightsPolicyAuthorizer } from "contracts/rights/RightsPolicyAuthorizer.sol";
import { IRightsPolicyAuthorizer } from "contracts/core/interfaces/rights/IRightsPolicyAuthorizer.sol";
import { IPolicyAuditor } from "contracts/core/interfaces/policies/IPolicyAuditor.sol";
import { PolicyBase } from "contracts/policies/PolicyBase.sol";
import { IAttestationProvider } from "contracts/core/interfaces/base/IAttestationProvider.sol";
import { T } from "contracts/core/primitives/Types.sol";

import { BaseTest } from "test/BaseTest.t.sol";

contract DummyAttestationProvider is IAttestationProvider {
    function getName() external pure returns (string memory) {
        return "DummyAttestationProvider";
    }

    function getAddress() external view returns (address) {
        return address(this);
    }

    function attest(
        address[] calldata recipients,
        uint256,
        bytes calldata
    ) external pure override returns (uint256[] memory attestationIds) {
        attestationIds = new uint256[](recipients.length);
    }

    function verify(uint256, address) external pure returns (bool) {
        return false;
    }
}

/// @dev Policy harness leveraging PolicyBase for authorizer testing.
contract PolicyBaseAuthorizerHarness is PolicyBase {
    IRightsPolicyAuthorizer public immutable AUTHORIZE_GATE;
    address private _lastHolder;
    bytes private _lastInitData;

    bool public setupShouldRevert;
    bool public setupRevertNoData;
    bool public triggerReentrancy;
    bool private _reentrancyExecuted;

    constructor(address rightsAuthorizer, address attestationProvider)
        PolicyBase(address(0), rightsAuthorizer, address(0), attestationProvider)
    {
        AUTHORIZE_GATE = IRightsPolicyAuthorizer(rightsAuthorizer);
    }

    function setSetupRevert(bool status) external {
        setupShouldRevert = status;
    }

    function setSetupRevertNoData(bool status) external {
        setupRevertNoData = status;
    }

    function setTriggerReentrancy(bool status) external {
        triggerReentrancy = status;
        _reentrancyExecuted = false;
    }

    function lastHolder() external view returns (address) {
        return _lastHolder;
    }

    function lastInit() external view returns (bytes memory) {
        return _lastInitData;
    }

    function setup(address holder, bytes calldata init) external virtual override {
        if (setupShouldRevert) {
            if (setupRevertNoData) {
                assembly {
                    revert(0, 0)
                }
            } else {
                revert("policy setup failed");
            }
        }
        if (triggerReentrancy && !_reentrancyExecuted) {
            _reentrancyExecuted = true;
            AUTHORIZE_GATE.authorizePolicy(address(this), init);
        }
        _lastHolder = holder;
        _lastInitData = init;
    }

    function enforce(address, T.Agreement calldata agreement) external pure override returns (uint256[] memory result) {
        result = new uint256[](agreement.parties.length);
    }

    function isAccessAllowed(address, bytes calldata) external pure override returns (bool) {
        return true;
    }


    function resolveTerms(bytes calldata) external pure override returns (T.Terms memory terms) {}

    function name() external pure override returns (string memory) {
        return "PolicyBaseAuthorizerHarness";
    }

    function description() external pure override returns (string memory) {
        return "Policy base authorizer harness";
    }
}

contract RightsPolicyAuthorizerTest is BaseTest {
    IRightsPolicyAuthorizer internal authorizer;
    IPolicyAuditor internal auditor;
    address internal holder;

    mapping(address => bool) internal audited;

    event RightsGranted(address indexed policy, address indexed holder, bytes data);
    event RightsRevoked(address indexed policy, address indexed holder);

    function setUp() public initialize {
        deployRightsPolicyAuthorizer();
        authorizer = IRightsPolicyAuthorizer(rightsPolicyAuthorizer);
        auditor = IPolicyAuditor(policyAudit);
        holder = user;
    }

    function _createPolicy()
        internal
        returns (PolicyBaseAuthorizerHarness policy, DummyAttestationProvider provider)
    {
        provider = new DummyAttestationProvider();
        policy = new PolicyBaseAuthorizerHarness(address(authorizer), address(provider));
    }

    function _auditPolicy(address policy) internal {
        if (audited[policy]) return;

        vm.prank(holder);
        try auditor.submit(policy) {} catch {}

        vm.prank(admin);
        try auditor.approve(policy) {
            audited[policy] = true;
        } catch {}

        if (!audited[policy] && auditor.isApproved(policy)) {
            audited[policy] = true;
        }
    }

    function _revokeAudit(address policy) internal {
        if (!audited[policy]) return;

        vm.prank(admin);
        try auditor.reject(policy) {
            audited[policy] = false;
        } catch {}

        if (audited[policy] && !auditor.isApproved(policy)) {
            audited[policy] = false;
        }
    }

    function test_Initialize_RevertsOnSecondCall() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(admin);
        RightsPolicyAuthorizer(address(authorizer)).initialize(accessManager);
    }

    function test_AuthorizePolicy_SucceedsForAuditedPolicy() public {
        (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();
        _auditPolicy(address(policy));

        bytes memory initData = abi.encode(uint256(1));
        vm.expectEmit(true, true, true, true, address(authorizer));
        emit RightsGranted(address(policy), holder, initData);

        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), initData);

        assertTrue(authorizer.isPolicyAuthorized(address(policy), holder), "Policy should be authorized");
        assertEq(policy.lastHolder(), holder, "Holder mismatch recorded in policy setup");
        assertEq(policy.lastInit(), initData, "Init payload mismatch in policy setup");
    }

    function test_AuthorizePolicy_RevertsWhenPolicyNotAudited() public {
        (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();

        assertFalse(authorizer.isPolicyAuthorized(address(policy), holder), "Policy should start unauthorized");

        vm.expectRevert(abi.encodeWithSelector(RightsPolicyAuthorizer.InvalidNotAuditedPolicy.selector, address(policy)));
        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), "");
    }

    function test_AuthorizePolicy_RevertsWhenSetupFails() public {
        (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();
        policy.setSetupRevert(true);
        policy.setSetupRevertNoData(true);
        _auditPolicy(address(policy));

        vm.expectRevert(
            abi.encodeWithSelector(
                RightsPolicyAuthorizer.InvalidPolicyInitialization.selector,
                "Error during policy initialization call"
            )
        );
        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), "");
    }

    function test_AuthorizePolicy_ReentrancyIsBlocked() public {
        (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();
        policy.setTriggerReentrancy(true);
        _auditPolicy(address(policy));

        vm.expectRevert(
            abi.encodeWithSelector(
                RightsPolicyAuthorizer.InvalidPolicyInitialization.selector,
                "Error during policy initialization call"
            )
        );
        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), "data");

        address[] memory holderPolicies = authorizer.getAuthorizedPolicies(holder);
        assertEq(holderPolicies.length, 0, "Reentrant attempt should not authorize policy");
        assertFalse(authorizer.isPolicyAuthorized(address(policy), holder), "Policy should remain unauthorized");
    }

    function test_RevokePolicy_RemovesAuthorization() public {
        (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();
        _auditPolicy(address(policy));

        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), "");

        vm.expectEmit(true, true, false, false, address(authorizer));
        emit RightsRevoked(address(policy), holder);

        vm.prank(holder);
        authorizer.revokePolicy(address(policy));

        assertFalse(authorizer.isPolicyAuthorized(address(policy), holder), "Policy should be revoked");
    }

    function test_RevokePolicy_RevertsWhenNotAuthorized() public {
        (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();

        vm.expectRevert(abi.encodeWithSelector(RightsPolicyAuthorizer.RevocationFailed.selector, holder, address(policy)));
        vm.prank(holder);
        authorizer.revokePolicy(address(policy));
    }

    function test_AuthorizePolicy_RevertsOnDuplicate() public {
        (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();
        _auditPolicy(address(policy));

        vm.startPrank(holder);
        authorizer.authorizePolicy(address(policy), "");

        vm.expectRevert(
            abi.encodeWithSelector(
                RightsPolicyAuthorizer.InvalidPolicyInitialization.selector,
                "Error during duplicated policy registration"
            )
        );
        authorizer.authorizePolicy(address(policy), "");
        vm.stopPrank();
    }

    function test_Integration_AuthorizeRevokeAndAuditFlow() public {
        (PolicyBaseAuthorizerHarness policyA, ) = _createPolicy();
        (PolicyBaseAuthorizerHarness policyB, ) = _createPolicy();
        _auditPolicy(address(policyA));
        _auditPolicy(address(policyB));

        vm.startPrank(holder);
        authorizer.authorizePolicy(address(policyA), abi.encode("A"));
        authorizer.authorizePolicy(address(policyB), abi.encode("B"));
        vm.stopPrank();

        address[] memory list = authorizer.getAuthorizedPolicies(holder);
        assertEq(list.length, 2, "Both policies should be present");
        assertTrue(list[0] != list[1], "Duplicate entries detected");

        vm.prank(holder);
        authorizer.revokePolicy(address(policyB));

        assertFalse(authorizer.isPolicyAuthorized(address(policyB), holder), "Policy B should be revoked");

        _revokeAudit(address(policyA));
        list = authorizer.getAuthorizedPolicies(holder);
        assertEq(list.length, 0, "Revoked or non-audited policies must be excluded");
    }

    function testFuzz_AuthorizePoliciesMaintainsConsistency(bytes32 salt) public {
        PolicyBaseAuthorizerHarness[3] memory policies;
        bool[3] memory expectedAuthorized;
        bool[3] memory expectedAudited;

        for (uint256 i = 0; i < policies.length; i++) {
            (PolicyBaseAuthorizerHarness policy, ) = _createPolicy();
            policies[i] = policy;
            _auditPolicy(address(policies[i]));
            expectedAudited[i] = true;
        }

        uint256 steps = 6;
        for (uint256 step = 0; step < steps; step++) {
            uint8 op = uint8(uint256(keccak256(abi.encode(salt, step)))) % 3;
            uint8 idx = uint8(uint256(keccak256(abi.encode(salt, step, "IDX")))) % uint8(policies.length);
            address policyAddr = address(policies[idx]);

            if (op == 0) {
                if (!expectedAudited[idx] || expectedAuthorized[idx]) continue;
                vm.prank(holder);
                authorizer.authorizePolicy(policyAddr, abi.encode(step));
                expectedAuthorized[idx] = true;
            } else if (op == 1) {
                if (!expectedAuthorized[idx]) continue;
                vm.prank(holder);
                authorizer.revokePolicy(policyAddr);
                expectedAuthorized[idx] = false;
            } else {
                bool auditStatus = uint8(uint256(keccak256(abi.encode(salt, step, "AUDIT")))) % 2 == 0;
                if (auditStatus) {
                    _auditPolicy(policyAddr);
                } else {
                    _revokeAudit(policyAddr);
                }
                expectedAudited[idx] = audited[policyAddr];
            }
        }

        address[] memory actual = authorizer.getAuthorizedPolicies(holder);
        address[] memory expected = new address[](policies.length);
        uint256 expectedLen;

        for (uint256 i = 0; i < policies.length; i++) {
            if (expectedAuthorized[i] && expectedAudited[i]) {
                expected[expectedLen++] = address(policies[i]);
            }
        }

        assertEq(actual.length, expectedLen, "Unexpected authorized length");
        for (uint256 i = 0; i < expectedLen; i++) {
            bool found;
            for (uint256 j = 0; j < actual.length; j++) {
                if (actual[j] == expected[i]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Expected policy missing");
        }
    }

}
