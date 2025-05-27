// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { QuorumUpgradeable } from "@synaps3/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { IHookRegistry } from "@synaps3/core/interfaces/lifecycle/IHookRegistry.sol";
import { IHook } from "@synaps3/core/interfaces/lifecycle/IHook.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

// Hook interfaces can define logic for:
// - Access control: e.g. only users holding certain tokens can access content.
// - Time-based rules: e.g. access available for a limited period.
// - Revenue sharing: e.g. split payments between creators or collaborators.
// This registry manages hooks based on their interface ID and ensures they implement IHook.

contract HookRegistry is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, QuorumUpgradeable, IHookRegistry {
    using ERC165Checker for address;

    /// @dev The interface ID for IHook, used to verify that a hook contract implements the correct interface.
    bytes4 private constant INTERFACE_HOOK = type(IHook).interfaceId;

    // Mapping from hook interface ID to hook contract address
    mapping(bytes4 => address) private _hooks;

    /// @notice Event emitted when a hook is registered.
    /// @param hook The address of the hook that has been registered.
    /// @param interfaceId The interface ID that the hook implements.
    /// @param submitter The address that submitted the hook.
    event HookRegistered(address indexed hook, bytes4 interfaceId, address submitter);

    /// @notice Event emitted when a hook is approved.
    /// @param hook The address of the hook that has been approved.
    /// @param auditor The address of the auditor who approved the hook.
    event HookApproved(address indexed hook, address auditor);

    /// @notice Event emitted when a hook is revoked.
    /// @param hook The address of the hook that has been revoked.
    /// @param auditor The address of the auditor who revoked the hook.
    event HookRevoked(address indexed hook, address auditor);

    /// @dev Error thrown when the hook contract does not implement the IHook interface.
    error InvalidHookContract(address);

    /// @dev Modifier to check that a hook contract implements the IHook interface.
    /// @param hook The address of the hook contract.
    /// Reverts if the hook does not implement the required interface.
    modifier onlyValidHook(address hook) {
        if (!hook.supportsInterface(INTERFACE_HOOK)) {
            revert InvalidHookContract(hook);
        }
        _;
    }

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// Prevent initialization of the logic contract
        _disableInitializers();
    }

    /// @notice Initializes the contract with the necessary configurations.
    /// This function is only called once upon deployment and sets up Quorum, UUPS, and Access control.
    function initialize(address accessManager) public initializer {
        __Quorum_init();
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Submit a hook for registration.
    /// @param hook The address of the hook contract to register.
    /// @param interfaceId The interface ID that this hook implements.
    /// This allows different kinds of hook logic to be categorized and retrieved by interface ID.
    // TODO: restricted to MOD_ROLE
    function submit(address hook, bytes4 interfaceId) external onlyValidHook(hook) restricted {
        _register(uint160(hook));
        _hooks[interfaceId] = hook;
        emit HookRegistered(hook, interfaceId, msg.sender);
    }

    /// @notice Approves a registered hook contract.
    /// @param hook The address of the hook to be approved.
    /// Emits a HookApproved event upon success.
    function approve(address hook) external onlyValidHook(hook) restricted {
        _approve(uint160(hook));
        emit HookApproved(hook, msg.sender);
    }

    /// @notice Revokes a previously approved hook contract.
    /// @param hook The address of the hook to revoke.
    /// Emits a HookRevoked event upon success.
    function reject(address hook) external onlyValidHook(hook) restricted {
        _revoke(uint160(hook));
        emit HookRevoked(hook, msg.sender);
    }

    /// @notice Returns the registered hook address for a given interface ID.
    /// @param interfaceId The interface ID used to look up the registered hook.
    /// @return The address of the hook associated with the given interface ID.
    function lookup(bytes4 interfaceId) external view returns (address) {
        return _hooks[interfaceId];
    }

    /// @notice Checks if a hook associated with an interface ID is active (i.e., approved).
    /// @param interfaceId The interface ID to check for an active hook.
    /// @return True if the hook is registered and its status is active, false otherwise.
    function isActive(bytes4 interfaceId) external view returns (bool) {
        address hook = _hooks[interfaceId];
        bool audited = _status(uint160(hook)) == T.Status.Active;
        return hook != address(0) && audited;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the admin can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
