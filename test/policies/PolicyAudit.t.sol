// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { PolicyAudit } from "contracts/policies/PolicyAudit.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessControlledUpgradeable } from "contracts/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { QuorumUpgradeable } from "contracts/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { IPolicy } from "contracts/core/interfaces/policies/IPolicy.sol";
import { T } from "contracts/core/primitives/Types.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { BaseTest } from "test/BaseTest.t.sol";

contract MockPolicy is ERC165, IPolicy {
    function setup(address, bytes calldata) external override {}

    function enforce(address, T.Agreement calldata) external pure override returns (uint256[] memory) {
        return new uint256[](0);
    }

    function isAccessAllowed(address, bytes calldata) external pure override returns (bool) {
        return true;
    }

    function getLicense(address, bytes calldata) external pure override returns (uint256) {
        return 0;
    }

    function resolveTerms(bytes calldata) external pure override returns (T.Terms memory) {
        return T.Terms({ amount: 0, currency: address(0), timeFrame: T.TimeFrame.NONE, uri: "" });
    }

    function getAttestationProvider() external pure override returns (address) {
        return address(0);
    }

    function name() external pure override returns (string memory) {
        return "Mock Policy";
    }

    function description() external pure override returns (string memory) {
        return "Mock policy for testing";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPolicy).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract NotPolicy {}

contract PolicyAuditHarness is PolicyAudit {
    function status(address policy) external view returns (T.Status) {
        return _status(uint160(policy));
    }
}

contract PolicyAuditTest is BaseTest {
    PolicyAuditHarness internal audit;
    address internal nonAdmin;

    function setUp() public initialize {
        PolicyAuditHarness implementation = new PolicyAuditHarness();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(PolicyAudit.initialize, accessManager)
        );
        audit = PolicyAuditHarness(address(proxy));
        nonAdmin = vm.addr(77);
    }

    function test_Submit_RevertWhen_InvalidPolicy() public {
        NotPolicy invalid = new NotPolicy();
        vm.expectRevert(abi.encodeWithSelector(PolicyAudit.InvalidPolicyContract.selector, address(invalid)));
        audit.submit(address(invalid));
    }

    function test_Submit_RegistersPolicy() public {
        MockPolicy policy = new MockPolicy();
        vm.expectEmit(true, true, false, true, address(audit));
        emit PolicyAudit.PolicySubmitted(address(policy), address(this));
        audit.submit(address(policy));
        assertEq(uint8(audit.status(address(policy))), uint8(T.Status.Waiting), "Status should be waiting");
        assertFalse(audit.isAudited(address(policy)), "Policy should not be active yet");
    }

    function test_Submit_RevertWhen_AlreadySubmitted() public {
        MockPolicy policy = new MockPolicy();
        audit.submit(address(policy));
        vm.expectRevert(QuorumUpgradeable.NotPendingApproval.selector);
        audit.submit(address(policy));
    }

    function test_Approve_TransitionsToActive() public {
        MockPolicy policy = new MockPolicy();
        audit.submit(address(policy));

        vm.expectEmit(true, true, false, true, address(audit));
        emit PolicyAudit.PolicyApproved(address(policy), admin);
        vm.prank(admin);
        audit.approve(address(policy));
        assertEq(uint8(audit.status(address(policy))), uint8(T.Status.Active), "Policy not active");
        assertTrue(audit.isAudited(address(policy)), "isAudited should be true");
    }

    function test_Approve_RevertWhen_NotWaiting() public {
        MockPolicy policy = new MockPolicy();
        vm.prank(admin);
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        audit.approve(address(policy));
    }

    function test_Reject_TransitionsToBlocked() public {
        MockPolicy policy = new MockPolicy();
        audit.submit(address(policy));
        vm.prank(admin);
        audit.approve(address(policy));

        vm.expectEmit(true, true, false, true, address(audit));
        emit PolicyAudit.PolicyRevoked(address(policy), admin);
        vm.prank(admin);
        audit.reject(address(policy));
        assertEq(uint8(audit.status(address(policy))), uint8(T.Status.Blocked), "Policy not blocked");
        assertFalse(audit.isAudited(address(policy)), "isAudited should be false after revoke");
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        vm.prank(admin);
        audit.approve(address(policy));
    }

    function test_Reject_RevertWhen_NotActive() public {
        MockPolicy policy = new MockPolicy();
        audit.submit(address(policy));
        vm.prank(admin);
        vm.expectRevert(QuorumUpgradeable.InvalidInactiveState.selector);
        audit.reject(address(policy));
    }

    function test_OnlyAdminMayApprove() public {
        MockPolicy policy = new MockPolicy();
        audit.submit(address(policy));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlledUpgradeable.InvalidUnauthorizedOperation.selector,
                "Only admin can perform this action."
            )
        );
        vm.prank(nonAdmin);
        audit.approve(address(policy));
    }

    function test_Integration_SubmitApproveRejectMultiple() public {
        MockPolicy policy1 = new MockPolicy();
        MockPolicy policy2 = new MockPolicy();
        MockPolicy policy3 = new MockPolicy();

        audit.submit(address(policy1));
        audit.submit(address(policy2));
        audit.submit(address(policy3));

        vm.prank(admin);
        audit.approve(address(policy1));
        vm.prank(admin);
        audit.approve(address(policy2));
        vm.prank(admin);
        audit.reject(address(policy2));

        assertTrue(audit.isAudited(address(policy1)), "Policy1 should be active");
        assertFalse(audit.isAudited(address(policy2)), "Policy2 should be blocked");
        assertEq(uint8(audit.status(address(policy3))), uint8(T.Status.Waiting), "Policy3 should remain waiting");
    }

    function testFuzz_SubmitMultiple(uint8 count) public {
        count = uint8(bound(count, 1, 25));
        for (uint8 i = 0; i < count; i++) {
            MockPolicy policy = new MockPolicy();
            audit.submit(address(policy));
            assertEq(uint8(audit.status(address(policy))), uint8(T.Status.Waiting), "Status should be waiting");
        }
    }

    function testFuzz_SubmitApprove(uint8 count) public {
        count = uint8(bound(count, 1, 20));
        for (uint8 i = 0; i < count; i++) {
            MockPolicy policy = new MockPolicy();
            audit.submit(address(policy));
            vm.prank(admin);
            audit.approve(address(policy));
            assertTrue(audit.isAudited(address(policy)), "Policy should be active");
        }
    }
}

contract PolicyAuditHandler is Test {
    PolicyAuditHarness public immutable audit;
    address public immutable admin;
    address[] internal policies;
    mapping(address => T.Status) internal statusStore;

    constructor(PolicyAuditHarness audit_, address admin_) {
        audit = audit_;
        admin = admin_;
    }

    function submitPolicy() external {
        MockPolicy policy = new MockPolicy();
        try audit.submit(address(policy)) {
            policies.push(address(policy));
            statusStore[address(policy)] = T.Status.Waiting;
        } catch {}
    }

    function approvePolicy(uint256 idx) external {
        if (policies.length == 0) return;
        address policy = policies[idx % policies.length];
        if (statusStore[policy] != T.Status.Waiting) return;

        vm.prank(admin);
        try audit.approve(policy) {
            statusStore[policy] = T.Status.Active;
        } catch {}
    }

    function rejectPolicy(uint256 idx) external {
        if (policies.length == 0) return;
        address policy = policies[idx % policies.length];
        if (statusStore[policy] != T.Status.Active) return;

        vm.prank(admin);
        try audit.reject(policy) {
            statusStore[policy] = T.Status.Blocked;
        } catch {}
    }

    function policiesLength() external view returns (uint256) {
        return policies.length;
    }

    function policyAt(uint256 idx) external view returns (address) {
        return policies[idx];
    }

    function storedStatus(address policy) external view returns (T.Status) {
        return statusStore[policy];
    }
}

contract PolicyAuditInvariantTest is BaseTest {
    PolicyAuditHarness audit;
    PolicyAuditHandler handler;

    function setUp() public initialize {
        PolicyAuditHarness implementation = new PolicyAuditHarness();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(PolicyAudit.initialize, accessManager)
        );
        audit = PolicyAuditHarness(address(proxy));

        handler = new PolicyAuditHandler(audit, admin);
        targetContract(address(handler));
    }

    function invariant_StatusSynchronization() external view {
        uint256 len = handler.policiesLength();
        for (uint256 i = 0; i < len; i++) {
            address policy = handler.policyAt(i);
            T.Status expected = handler.storedStatus(policy);
            assertEq(uint8(audit.status(policy)), uint8(expected), "Status mismatch");
        }
    }

    function invariant_IsAuditedMatchesActive() external view {
        uint256 len = handler.policiesLength();
        for (uint256 i = 0; i < len; i++) {
            address policy = handler.policyAt(i);
            bool audited = audit.isAudited(policy);
            bool expected = handler.storedStatus(policy) == T.Status.Active;
            assertEq(audited, expected, "isAudited mismatch");
        }
    }
}
