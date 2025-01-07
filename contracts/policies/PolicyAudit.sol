// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { QuorumUpgradeable } from "@synaps3/core/primitives/upgradeable/QuorumUpgradeable.sol";

import { IPolicy } from "@synaps3/core/interfaces/policies/IPolicy.sol";
import { IPolicyAuditor } from "@synaps3/core/interfaces/policies/IPolicyAuditor.sol";

/// @title PolicyAudit
/// @notice This contract audits content policies and ensures that only authorized entities can approve or revoke.
contract PolicyAudit is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, QuorumUpgradeable, IPolicyAuditor {
    using ERC165Checker for address;
    /// @dev The interface ID for IPolicy, used to verify that a policy contract implements the correct interface.
    bytes4 private constant INTERFACE_POLICY = type(IPolicy).interfaceId;

    /// @dev Error thrown when the policy contract does not implement the IPolicy interface.
    error InvalidPolicyContract(address);

    /// @notice Event emitted when a policy is submitted for audit.
    /// @param policy The address of the policy that has been submitted.
    /// @param submitter The address of the account that submitted the policy for audit.
    event PolicySubmitted(address indexed policy, address submitter);

    /// @notice Event emitted when a policy audit is approved.
    /// @param policy The address of the policy that has been audited.
    /// @param auditor The address of the auditor that approved the audit.
    event PolicyApproved(address indexed policy, address auditor);

    /// @notice Event emitted when a policy audit is revoked.
    /// @param policy The address of the policy whose audit has been revoked.
    /// @param auditor The address of the auditor that revoked the audit.
    event PolicyRevoked(address indexed policy, address auditor);

    /// @dev Modifier to check that a policy contract implements the IPolicy interface.
    /// @param policy The address of the license policy contract.
    /// Reverts if the policy does not implement the required interface.
    modifier onlyValidPolicy(address policy) {
        if (!policy.supportsInterface(INTERFACE_POLICY)) {
            revert InvalidPolicyContract(policy);
        }
        _;
    }

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the necessary configurations.
    /// This function is only called once upon deployment and sets up Quorum, UUPS, and Governable features.
    function initialize(address accessManager) public initializer {
        __Quorum_init();
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    // TODO method to list audited policies

    /// @notice Submits an audit request for the given policy.
    /// This registers the policy for audit within the system.
    /// @param policy The address of the policy to be submitted for auditing.
    function submit(address policy) external onlyValidPolicy(policy) {
        _register(uint160(policy));
        emit PolicySubmitted(policy, msg.sender);
    }

    /// @notice Approves the audit of a given policy by a specified auditor.
    /// @param policy The address of the policy to be audited.
    /// @dev This function emits the PolicyApproved event upon successful audit approval.
    function approve(address policy) external onlyValidPolicy(policy) restricted {
        _approve(uint160(policy));
        emit PolicyApproved(policy, msg.sender);
    }

    /// @notice Revokes the audit of a given policy by a specified auditor.
    /// @param policy The address of the policy whose audit is to be revoked.
    /// @dev This function emits the PolicyRevoked event upon successful audit revocation.
    function reject(address policy) external onlyValidPolicy(policy) restricted {
        _revoke(uint160(policy));
        emit PolicyRevoked(policy, msg.sender);
    }

    /// @notice Checks if a specific policy contract has been audited.
    /// @param policy The address of the policy contract to verify.
    function isAudited(address policy) external view returns (bool) {
        return _status(uint160(policy)) == Status.Active;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
