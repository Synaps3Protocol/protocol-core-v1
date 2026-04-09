// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagerUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import { C } from "@synaps3/core/primitives/Constants.sol";

/// @title AccessManager
/// @notice Manages roles and permissions across the Synapse protocol.
/// @dev Implements OpenZeppelin's `AccessManagerUpgradeable` with a structured role hierarchy.
///      Uses a UUPS (Universal Upgradeable Proxy Standard) mechanism for upgradeability.
contract AccessManager is Initializable, UUPSUpgradeable, AccessManagerUpgradeable {
    /// @notice Initializes the proxy state.
    function initialize(address initialAdmin) public override initializer {
        __UUPSUpgradeable_init();
        __AccessManager_init(initialAdmin);

        // Initially all the the roles are managed by admin
        // since gov role has not role admin set, admin is by default
        // based on default values for _roles struct mapping(uint64 roleId => Role) _roles;
        // any not granted nor found _roles[roleId] = Role({admin: 0, ...}).

        // contracts/access/manager/AccessManagerUpgradeable.sol#L697
        // contracts/access/manager/AccessManagerUpgradeable.sol#L738C8-L738C100
        // if (selector == this.grantRole.selector || selector == this.revokeRole.selector) {
        //     // First argument is a roleId.
        //     uint64 roleId = abi.decode(data[0x04:0x24], (uint64));
        //     return (true, getRoleAdmin(roleId), 0); // => (true, 0, 0)
        // }

        // Multisig Assignment & Rotation
        // ───────────────────────────────────────────────────────────────
        //
        // All operational multisigs (Admin, Pauser, Councils, Treasury signers)
        // are granted and managed by the Community Governance (GOV_ROLE).
        // Any rotation, addition, or removal of a signer or council member
        // must be approved by governance through a proposal, queued in the Timelock,
        // and executed on-chain.
        //
        // This ensures that the execution layer (multisigs) remains accountable
        // to the collective will of the community.

        // Strategic roles for governance classification within the protocol
        // ───────────────────────────────────────────────────────────────
        //
        // Community Governance Role:
        // - GOV_ROLE: Represents decentralized community governance.
        //   Decisions are made collectively through token-weighted, quadratic,
        //   or other approved voting mechanisms, and executed via a Timelock
        //   (e.g., 48–72 hours delay) for transparency and reaction time.
        //
        // Group / Council-Based Roles:
        // - ADMIN_ROLE: Managed by a multisig smart account.
        //   Approves policy attestations, contract upgrades,
        //   hook registrations, and moderates operational parameters.
        //
        // - SEC_ROLE: Managed by a designated security council multisig or EOA.
        //   Authorized to pause protocol modules for monitoring, threat mitigation,
        //   or emergency response; actions must be reported and are subject to limits.
        //
        // - TREASURER_ROLE: Managed by a treasury multisig smart account.
        //   Executes disbursements and manages treasury flows within spending limits
        //   and policies set by the Community Governance (GOV_ROLE).
        //
        // - CONTENT_COUNCIL_ROLE: Managed by a multisig smart account.
        //   Participates in governance referenda and oversees content curation policies.
        //
        // - CUSTODY_COUNCIL_ROLE: Managed by a multisig smart account.
        //   Participates in governance referenda for node/custodian validation policies.
        //
        // Individual / Contract-Based Roles:
        // - OPS_ROLE: Internal operational role assigned to protocol-trusted contracts,
        //   enabling direct interaction with core modules. No human control.
        // - VER_ROLE: Individual role granted to trusted creators,
        //   allowing them to upload content without conventional KYC-style verification.

        // OPS_ROLE
        // ───────────────────────────────────────────────────────────────
        // Critical operational role used by internal protocol contracts
        // (e.g., Vault, Escrow) to call sensitive functions like lockFunds
        // and releaseFunds.
        //
        // The roleAdmin of OPS_ROLE is held by the ADMIN_ROLE multisig,
        // which itself is controlled by Community Governance (GOV_ROLE)
        // via proposals + timelock and supervised by SEC_ROLE guardian.
        //
        // This design preserves flexibility to onboard future audited
        // protocol modules while preventing unilateral assignment:
        // any change requires a governance proposal, a timelock delay,
        // and transparent on-chain execution with published audit evidence.
        //
        // OPS_ROLE must never be granted to EOAs or multisigs directly.

        // Hierarchy / Relationship Diagram
        // ───────────────────────────────────────────────────────────────
        /*
            GOV_ROLE (Community Governance)
            │
            ├── ADMIN_ROLE (Multisig Council)
            │     ├── OPS_ROLE (Internal Contract Role)
            │     └── SEC_ROLE (Security Council / Guardian)
            │
            ├── TREASURER_ROLE (Treasury Multisig under GOV policy)
            │
            ├── CONTENT_COUNCIL_ROLE (Multisig Council)
            │
            ├── CUSTODY_COUNCIL_ROLE (Multisig Council)
            │
            └── VER_ROLE (Individual Trusted Creator)
        */

        // Proposals Lifecycle (per-domain)
        // ───────────────────────────────────────────────────────────────
        //   PROPOSER (domain governor/council)    EXECUTOR (domain timelock)
        //        └─────────────── propose/schedule ───────────────┘
        //   domain  ──>  domain Timelock (delay)  ──>  execution on domain modules
        //
        // Example:
        //   admin-governor (only allowlisted proposers) ──> AdminTimelock ──> Admin modules
        //
        // Notes:
        // • Each domain has its own Governor (proposers allowlisted) and its own Timelock.
        // • The domain Timelock is the ONLY authority recognized by that domain’s modules
        //   (i.e., it holds the role or is the roleAdmin for that domain).
        // • EXECUTOR is typically open (EXECUTOR_ROLE = address(0)); anyone can execute after delay.
        // • SEC_ROLE: emergency actions MAY execute directly (no timelock) with strict scope limits.

        // Role Admin Hierarchy (as configured)
        // ───────────────────────────────────────────────────────────────
        // Admin domain controls low-level ops & security roles:
        _setRoleAdmin(C.OPS_ROLE, C.ADMIN_ROLE);
        _setRoleAdmin(C.SEC_ROLE, C.ADMIN_ROLE);

        // Governance domain controls councils & treasury/community-facing roles:
        _setRoleAdmin(C.VER_ROLE, C.GOV_ROLE);
        _setRoleAdmin(C.ADMIN_ROLE, C.GOV_ROLE); // locked role
        _setRoleAdmin(C.TREASURER_ROLE, C.GOV_ROLE);
        _setRoleAdmin(C.CUSTODY_COUNCIL_ROLE, C.GOV_ROLE);
        _setRoleAdmin(C.CONTENT_COUNCIL_ROLE, C.GOV_ROLE);
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the admin can authorize the upgrade.
    function _authorizeUpgrade(address) internal view override {
        (bool isMember, ) = hasRole(C.ADMIN_ROLE, msg.sender);
        // solhint-disable-next-line gas-custom-errors
        require(isMember, "Only admin can authorize the upgrade");
    }
}
