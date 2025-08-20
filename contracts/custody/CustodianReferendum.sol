// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// solhint-disable-next-line max-line-length
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { QuorumUpgradeable } from "@synaps3/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { ICustodianReferendum } from "@synaps3/core/interfaces/custody/ICustodianReferendum.sol";
import { ICustodianFactory } from "@synaps3/core/interfaces/custody/ICustodianFactory.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @title CustodianReferendum
/// @notice Manages the registration, approval, and revocation of content custodians.
/// @dev Implements `ICustodianReferendum` and ensures that only valid custodians can operate.
///      This contract integrates with `LedgerVault` for financial management, `Tollgate` for fee validation,
///      and `Treasury` for protocol-wide economic operations.
contract CustodianReferendum is
    Initializable,
    UUPSUpgradeable,
    QuorumUpgradeable,
    AccessControlledUpgradeable,
    ICustodianReferendum
{
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ICustodianFactory public immutable CUSTODIAN_FACTORY;
    //slither-disable-end naming-convention

    /// @dev Tracks the number of active enrollments within the system.
    uint256 private _enrollmentsCount;
    /// @notice Event emitted when a custodian is registered
    /// @param custodian The address of the registered custodian
    event Registered(address indexed custodian);

    /// @notice Event emitted when a custodian is approved
    /// @param custodian The address of the approved custodian
    event Approved(address indexed custodian);

    /// @notice Event emitted when a custodian is revoked
    /// @param custodian The address of the revoked custodian
    event Revoked(address indexed custodian);

    /// @notice Error thrown when the custodian is not recognized by the factory.
    /// @param custodian The address of the unregistered custodian contract.
    error UnregisteredCustodian(address custodian);

    /// @notice Modifier to ensure the custodian was deployed through the trusted factory.
    /// @param custodian The address of the custodian contract to verify.
    modifier onlyValidCustodian(address custodian) {
        // ensure the custodian was deployed through the trusted factory and is known to the protocol
        if (!CUSTODIAN_FACTORY.isRegistered(custodian)) {
            revert UnregisteredCustodian(custodian);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address custodianFactory) {
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        _disableInitializers();
        CUSTODIAN_FACTORY = ICustodianFactory(custodianFactory);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __Quorum_init();
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Checks if the entity is active.
    /// @dev This function verifies the active status of the custodian.
    /// @param custodian The custodian's address to check.
    function isActive(address custodian) external view returns (bool) {
        // TODO add stateful management to custodians contract, the custodian can
        // change his state to "maintenance mode" or "inactive" if its facing issues
        // in that way the custodian is omitted during load balancing.
        // in this line we can check if the custodian contract is active custodian.isActive()
        // this is important feature if the custodians want to avoid harm reputation

        return _status(uint160(custodian)) == T.Status.Active;
    }

    /// @notice Checks if the entity is waiting.
    /// @dev This function verifies the waiting status of the custodian.
    /// @param custodian The custodian's address to check.
    function isWaiting(address custodian) external view returns (bool) {
        return _status(uint160(custodian)) == T.Status.Waiting;
    }

    /// @notice Checks if the entity is blocked.
    /// @dev This function verifies the blocked status of the custodian.
    /// @param custodian The custodian's address to check.
    function isBlocked(address custodian) external view returns (bool) {
        return _status(uint160(custodian)) == T.Status.Blocked;
    }

    /// @notice Registers a custodian to be approved by council.
    /// @param custodian The address of the custodian to register.
    function register(address custodian) external onlyValidCustodian(custodian) {
        // register custodian as pending approval
        _register(uint160(custodian));
        // set the custodian active enrollment period..
        emit Registered(custodian);
    }

    /// @notice Approves a custodian's registration.
    /// @param custodian The address of the custodian to approve.
    function approve(address custodian) external restricted {
        _approve(uint160(custodian));
        _enrollmentsCount++;
        emit Approved(custodian);
    }

    /// @notice Revokes the registration of a custodian.
    /// @param custodian The address of the custodian to revoke.
    function revoke(address custodian) external restricted {
        _revoke(uint160(custodian));
        _enrollmentsCount--;
        emit Revoked(custodian);
    }

    /// @notice Retrieves the total number of enrollments.
    function getEnrollmentCount() external view returns (uint256) {
        return _enrollmentsCount;
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
