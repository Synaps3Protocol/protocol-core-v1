// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { RightsPolicyAuthorizer } from "contracts/rights/RightsPolicyAuthorizer.sol";
import { IRightsPolicyAuthorizer } from "contracts/core/interfaces/rights/IRightsPolicyAuthorizer.sol";
import { IPolicy } from "contracts/core/interfaces/policies/IPolicy.sol";
import { IPolicyAuditor } from "contracts/core/interfaces/policies/IPolicyAuditor.sol";
import { T } from "contracts/core/primitives/Types.sol";

import { BaseTest } from "test/BaseTest.t.sol";

/// @dev Minimal policy mock exposing setup side-effects for assertions.
contract PolicyMock is ERC165, IPolicy {
    address public lastHolder;
    bytes public lastInit;
    bool public shouldRevert;

    function configureRevert(bool status) external {
        shouldRevert = status;
    }

    /// @inheritdoc IPolicy
    function setup(address holder, bytes calldata init) public virtual override {
        if (shouldRevert) revert("policy setup failed");
        lastHolder = holder;
        lastInit = init;
    }

    /// @inheritdoc IPolicy
    function enforce(address, T.Agreement calldata) external pure override returns (uint256[] memory result) {
        return result;
    }

    /// @inheritdoc IPolicy
    function isAccessAllowed(address, bytes calldata) external pure override returns (bool) {
        return false;
    }

    /// @inheritdoc IPolicy
    function getLicense(address, bytes calldata) external pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IPolicy
    function resolveTerms(bytes calldata) external pure override returns (T.Terms memory terms) {
        return terms;
    }

    /// @inheritdoc IPolicy
    function getAttestationProvider() external pure override returns (address) {
        return address(0);
    }

    /// @inheritdoc IPolicy
    function name() external pure override returns (string memory) {
        return "MockPolicy";
    }

    /// @inheritdoc IPolicy
    function description() external pure override returns (string memory) {
        return "Mock policy used for testing";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPolicy).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract PolicyNoDataRevertMock is PolicyMock {
    function setup(address, bytes calldata) public pure override {
        assembly {
            revert(0, 0)
        }
    }
}

/// @dev Policy mock exercising reentrancy protection.
contract ReentrantPolicyMock is PolicyMock {
    IRightsPolicyAuthorizer public immutable authorizer;
    bool private triggered;

    constructor(IRightsPolicyAuthorizer authorizer_) {
        authorizer = authorizer_;
    }

    function setup(address holder, bytes calldata init) public override {
        if (triggered) return;
        triggered = true;
        authorizer.authorizePolicy(address(this), init);
        super.setup(holder, init);
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

    function _auditPolicy(address policy) internal {
        if (audited[policy]) return;

        vm.prank(holder);
        try auditor.submit(policy) {} catch {}

        vm.prank(admin);
        try auditor.approve(policy) {
            audited[policy] = true;
        } catch {}

        if (!audited[policy] && auditor.isAudited(policy)) {
            audited[policy] = true;
        }
    }

    function _revokeAudit(address policy) internal {
        if (!audited[policy]) return;

        vm.prank(admin);
        try auditor.reject(policy) {
            audited[policy] = false;
        } catch {}

        if (audited[policy] && !auditor.isAudited(policy)) {
            audited[policy] = false;
        }
    }

    function test_Initialize_RevertsOnSecondCall() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vm.prank(admin);
        RightsPolicyAuthorizer(address(authorizer)).initialize(accessManager);
    }

    function test_AuthorizePolicy_SucceedsForAuditedPolicy() public {
        PolicyMock policy = new PolicyMock();
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
        PolicyMock policy = new PolicyMock();

        vm.expectRevert(abi.encodeWithSelector(RightsPolicyAuthorizer.InvalidNotAuditedPolicy.selector, address(policy)));
        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), "");
    }

    function test_AuthorizePolicy_RevertsWhenSetupFails() public {
        PolicyNoDataRevertMock policy = new PolicyNoDataRevertMock();
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
        ReentrantPolicyMock policy = new ReentrantPolicyMock(authorizer);
        _auditPolicy(address(policy));

        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), "data");

        address[] memory holderPolicies = authorizer.getAuthorizedPolicies(holder);
        assertEq(holderPolicies.length, 1, "Holder should keep a single authorized policy");
        assertEq(holderPolicies[0], address(policy), "Unexpected policy stored for holder");

        assertFalse(
            authorizer.isPolicyAuthorized(address(policy), address(policy)),
            "Reentrancy guard should prevent policy self-authorization"
        );
    }

    function test_RevokePolicy_RemovesAuthorization() public {
        PolicyMock policy = new PolicyMock();
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
        PolicyMock policy = new PolicyMock();

        vm.expectRevert(abi.encodeWithSelector(RightsPolicyAuthorizer.RevocationFailed.selector, holder, address(policy)));
        vm.prank(holder);
        authorizer.revokePolicy(address(policy));
    }

    function test_AuthorizePolicy_RevertsOnDuplicate() public {
        PolicyMock policy = new PolicyMock();
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

    function test_GetAuthorizedPolicies_FiltersOutNonAudited() public {
        PolicyMock policy = new PolicyMock();
        _auditPolicy(address(policy));

        vm.prank(holder);
        authorizer.authorizePolicy(address(policy), "");

        address[] memory authorizedBefore = authorizer.getAuthorizedPolicies(holder);
        assertEq(authorizedBefore.length, 1, "Authorized list should include policy");

        _revokeAudit(address(policy));

        address[] memory authorizedAfter = authorizer.getAuthorizedPolicies(holder);
        assertEq(authorizedAfter.length, 0, "Non-audited policies must be filtered out");
    }

    function test_GetAuthorizedPolicies_ReturnsUniqueAuthorizedEntries() public {
        PolicyMock policyA = new PolicyMock();
        PolicyMock policyB = new PolicyMock();
        _auditPolicy(address(policyA));
        _auditPolicy(address(policyB));

        vm.startPrank(holder);
        authorizer.authorizePolicy(address(policyA), "A");
        authorizer.authorizePolicy(address(policyB), "B");
        vm.stopPrank();

        address[] memory authorized = authorizer.getAuthorizedPolicies(holder);
        assertEq(authorized.length, 2, "Two policies expected");
        assertTrue(authorized[0] != authorized[1], "Duplicate entries detected");
    }

    function test_IsPolicyAuthorized_ReturnsFalseWhenNeverAuthorized() public {
        PolicyMock policy = new PolicyMock();
        _auditPolicy(address(policy));

        assertFalse(authorizer.isPolicyAuthorized(address(policy), holder), "Policy should not be authorized");
    }

    function test_Integration_AuthorizeRevokeAndAuditFlow() public {
        PolicyMock policyA = new PolicyMock();
        PolicyMock policyB = new PolicyMock();
        _auditPolicy(address(policyA));
        _auditPolicy(address(policyB));

        vm.startPrank(holder);
        authorizer.authorizePolicy(address(policyA), abi.encode("A"));
        authorizer.authorizePolicy(address(policyB), abi.encode("B"));
        vm.stopPrank();

        address[] memory list = authorizer.getAuthorizedPolicies(holder);
        assertEq(list.length, 2, "Both policies should be present");

        vm.prank(holder);
        authorizer.revokePolicy(address(policyB));

        assertFalse(authorizer.isPolicyAuthorized(address(policyB), holder), "Policy B should be revoked");

        _revokeAudit(address(policyA));
        list = authorizer.getAuthorizedPolicies(holder);
        assertEq(list.length, 0, "Revoked or non-audited policies must be excluded");
    }

    function testFuzz_AuthorizePoliciesMaintainsConsistency(bytes32 salt) public {
        PolicyMock[3] memory policies;
        bool[3] memory expectedAuthorized;
        bool[3] memory expectedAudited;

        for (uint256 i = 0; i < policies.length; i++) {
            policies[i] = new PolicyMock();
            _auditPolicy(address(policies[i]));
            expectedAudited[i] = true;
        }

        uint256 steps = 12;
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

contract RightsPolicyAuthorizerHandler is Test {
    IRightsPolicyAuthorizer public immutable authorizer;
    IPolicyAuditor public immutable auditor;
    address public immutable holder;
    address public immutable admin;

    PolicyMock[] internal policies;
    mapping(address => bool) internal authorized;
    mapping(address => bool) internal audited;

    constructor(IRightsPolicyAuthorizer authorizer_, IPolicyAuditor auditor_, address holder_, address admin_) {
        authorizer = authorizer_;
        auditor = auditor_;
        holder = holder_;
        admin = admin_;

        for (uint256 i = 0; i < 3; i++) {
            PolicyMock policy = new PolicyMock();
            policies.push(policy);
            _audit(address(policy));
        }
    }

    function _audit(address policy) internal {
        if (audited[policy]) return;

        vm.prank(holder);
        try auditor.submit(policy) {} catch {}

        vm.prank(admin);
        try auditor.approve(policy) {
            audited[policy] = true;
        } catch {}

        if (!audited[policy] && auditor.isAudited(policy)) {
            audited[policy] = true;
        }
    }

    function policiesLength() external view returns (uint256) {
        return policies.length;
    }

    function policyAt(uint256 idx) external view returns (address) {
        return address(policies[idx]);
    }

    function isAuthorized(address policy) external view returns (bool) {
        return authorized[policy] && audited[policy] && auditor.isAudited(policy);
    }

    function authorize(uint256 seed) external {
        PolicyMock policy = policies[seed % policies.length];
        address addr = address(policy);

        _audit(addr);
        if (!audited[addr]) return;

        vm.prank(holder);
        try authorizer.authorizePolicy(addr, abi.encode(seed)) {
            authorized[addr] = true;
        } catch {}
    }

    function revoke(uint256 seed) external {
        PolicyMock policy = policies[seed % policies.length];
        address addr = address(policy);
        if (!authorized[addr]) return;

        vm.prank(holder);
        try authorizer.revokePolicy(addr) {
            authorized[addr] = false;
        } catch {}
    }

    function toggleAudit(uint256 seed, bool status) external {
        PolicyMock policy = policies[seed % policies.length];
        address addr = address(policy);

        if (status) {
            _audit(addr);
        } else if (audited[addr]) {
            vm.prank(admin);
            try auditor.reject(addr) {
                audited[addr] = false;
                authorized[addr] = false;
            } catch {}
        }
    }
}

contract RightsPolicyAuthorizerInvariantTest is BaseTest {
    IRightsPolicyAuthorizer internal authorizer;
    IPolicyAuditor internal auditor;
    RightsPolicyAuthorizerHandler internal handler;

    function setUp() public initialize {
        deployRightsPolicyAuthorizer();
        authorizer = IRightsPolicyAuthorizer(rightsPolicyAuthorizer);
        auditor = IPolicyAuditor(policyAudit);

        handler = new RightsPolicyAuthorizerHandler(authorizer, auditor, user, admin);
        targetContract(address(handler));
    }

    function invariant_NoZeroOrUnauditedPoliciesInSet() external {
        address[] memory list = authorizer.getAuthorizedPolicies(user);

        for (uint256 i = 0; i < list.length; i++) {
            address policy = list[i];
            assertTrue(policy != address(0), "Authorized list should not contain zero address");
            assertTrue(auditor.isAudited(policy), "Authorized list should only include audited policies");

            for (uint256 j = 0; j < i; j++) {
                require(list[j] != policy, "Authorized list should contain unique policies");
            }
        }
    }

    function invariant_AuthorizationReflectsHandlerState() external {
        for (uint256 i = 0; i < handler.policiesLength(); i++) {
            address policy = handler.policyAt(i);
            bool expected = handler.isAuthorized(policy);
            bool actual = authorizer.isPolicyAuthorized(policy, user);
            assertEq(actual, expected, "Authorization state mismatch");
        }
    }
}
