// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { QuorumUpgradeable } from "contracts/base/upgradeable/QuorumUpgradeable.sol";

import { IPolicy } from "contracts/interfaces/policies/IPolicy.sol";
import { IPolicyAuditor } from "contracts/interfaces/policies/IPolicyAuditor.sol";

/// @title PolicyAudit
/// @notice This contract audits content policies and ensures that only authorized entities can approve or revoke policy audits.
/// It is designed to be upgradeable using UUPS and governed by a decentralized authority.
/// @dev The contract uses OpenZeppelin's UUPS (Universal Upgradeable Proxy Standard) mechanism and Governable for governance control.
contract PolicyAudit is Initializable, UUPSUpgradeable, GovernableUpgradeable, QuorumUpgradeable, IPolicyAuditor {
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
    modifier onlyPolicyContract(address policy) {
        if (!policy.supportsInterface(INTERFACE_POLICY)) {
            revert InvalidPolicyContract(policy);
        }
        _;
    }

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @notice This constructor ensures the implementation contract cannot be initialized, as recommended for UUPS implementations.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the necessary configurations.
    /// This function is only called once upon deployment and sets up Quorum, UUPS, and Governable features.
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
    }

    /// @notice Submits an audit request for the given policy.
    /// This registers the policy for audit within the system.
    /// @param policy The address of the policy to be submitted for auditing.
    function submit(address policy) external onlyPolicyContract(policy) {
        _register(uint160(policy));
        emit PolicySubmitted(policy, msg.sender);
    }

    /// @notice Approves the audit of a given policy by a specified auditor.
    /// @param policy The address of the policy to be audited.
    /// @dev This function emits the PolicyApproved event upon successful audit approval.
    function approve(address policy) external onlyPolicyContract(policy) onlyMod {
        _approve(uint160(policy));
        emit PolicyApproved(policy, msg.sender);
    }

    /// @notice Revokes the audit of a given policy by a specified auditor.
    /// @param policy The address of the policy whose audit is to be revoked.
    /// @dev This function emits the PolicyRevoked event upon successful audit revocation.
    function reject(address policy) external onlyPolicyContract(policy) onlyMod {
        _revoke(uint160(policy));
        emit PolicyRevoked(policy, msg.sender);
    }

    /// @notice Checks if a specific policy contract has been audited.
    /// @param policy The address of the policy contract to verify.
    /// @return bool Returns true if the policy is audited, false otherwise.
    function isAudited(address policy) external view returns (bool) {
        return _status(uint160(policy)) == Status.Active;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
