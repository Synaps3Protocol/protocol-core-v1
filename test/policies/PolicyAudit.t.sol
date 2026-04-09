// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { PolicyAudit } from "contracts/policies/PolicyAudit.sol";
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

contract PolicyAuditTest is BaseTest {
    PolicyAudit internal audit;
    address internal nonAdmin;

    function setUp() public initialize {
        deployPolicyAudit();
        audit = PolicyAudit(policyAudit);
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
        assertTrue(audit.isPending(address(policy)), "Policy should be pending approval");
        assertFalse(audit.isRejected(address(policy)), "Policy should not be rejected");
        assertFalse(audit.isApproved(address(policy)), "Policy should not be approved yet");
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
        assertTrue(audit.isApproved(address(policy)), "Policy should be approved");
        assertFalse(audit.isRejected(address(policy)), "Policy should not be rejected");
        assertFalse(audit.isPending(address(policy)), "Policy should not remain pending");
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
        assertFalse(audit.isApproved(address(policy)), "Policy should no longer be approved");
        assertTrue(audit.isRejected(address(policy)), "Policy should be rejected");
        assertFalse(audit.isPending(address(policy)), "Rejected policy should not be pending");
        vm.startPrank(admin);
        vm.expectRevert(QuorumUpgradeable.NotWaitingApproval.selector);
        audit.approve(address(policy));
        vm.stopPrank();
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

        assertTrue(audit.isApproved(address(policy1)), "Policy1 should be active");
        assertFalse(audit.isApproved(address(policy2)), "Policy2 should be blocked");
        assertTrue(audit.isRejected(address(policy2)), "Policy2 should be rejected");
        assertFalse(audit.isApproved(address(policy3)), "Policy3 should remain unapproved");
        assertFalse(audit.isRejected(address(policy3)), "Policy3 should not be rejected");
        assertTrue(audit.isPending(address(policy3)), "Policy3 should remain pending");
    }
}
