// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// solhint-disable-next-line max-line-length
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { QuorumUpgradeable } from "@synaps3/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { ICustodian } from "@synaps3/core/interfaces/custody/ICustodian.sol";
import { IAgreementSettler } from "@synaps3/core/interfaces/financial/IAgreementSettler.sol";
import { IFeeSchemeValidator } from "@synaps3/core/interfaces/economics/IFeeSchemeValidator.sol";
import { ICustodianReferendum } from "@synaps3/core/interfaces/custody/ICustodianReferendum.sol";
import { ICustodianFactory } from "@synaps3/core/interfaces/custody/ICustodianFactory.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
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
    ICustodianReferendum,
    IFeeSchemeValidator
{
    using FinancialOps for address;
    using ERC165Checker for address;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAgreementSettler public immutable AGREEMENT_SETTLER;
    ICustodianFactory public immutable CUSTODIAN_FACTORY;
    //slither-disable-end naming-convention

    /// @dev Defines the expiration period for enrollment, determining how long a custodian remains active.
    uint256 private _expirationPeriod;
    /// @dev Tracks the number of active enrollments within the system.
    uint256 private _enrollmentsCount;
    /// @dev Maps a custodian's address to their respective enrollment deadline timestamp.
    mapping(address => uint256) private _enrollmentDeadline;

    /// @notice Event emitted when a custodian is registered
    /// @param custodian The address of the registered custodian
    /// @param paidFees The amount of fees that were paid upon registration
    event Registered(address indexed custodian, uint256 paidFees);

    /// @notice Event emitted when a custodian is approved
    /// @param custodian The address of the approved custodian
    event Approved(address indexed custodian);

    /// @notice Event emitted when a custodian is revoked
    /// @param custodian The address of the revoked custodian
    event Revoked(address indexed custodian);

    /// @notice Emitted when a new period is set
    /// @param newPeriod The new period that is set, could be in seconds, blocks, or any other unit
    event PeriodSet(uint256 newPeriod);

    /// @notice Error thrown when the custodian is not recognized by the factory.
    /// @param custodian The address of the unregistered custodian contract.
    error UnregisteredCustodian(address custodian);

    /// @notice Error thrown when the custodian does not match the agreement's registered party.
    /// @param custodian The custodian provided for the operation.s
    error CustodianAgreementMismatch(address custodian);

    /// @notice Modifier to ensure the custodian was deployed through the trusted factory and is registered in the system.
    /// @param custodian The address of the custodian contract to verify.
    modifier onlyValidCustodian(address custodian) {
        // ensure the custodian was deployed through the trusted factory and is known to the protocol
        if (!CUSTODIAN_FACTORY.isRegistered(custodian)) {
            revert UnregisteredCustodian(msg.sender);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address agreementSettler, address custodianFactory) {
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        _disableInitializers();
        AGREEMENT_SETTLER = IAgreementSettler(agreementSettler);
        CUSTODIAN_FACTORY = ICustodianFactory(custodianFactory);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __Quorum_init();
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
        // 6 months initially..
        _expirationPeriod = 180 days;
    }

    /// @notice Checks if the given fee scheme is supported in this context.
    /// @param scheme The fee scheme to validate.
    /// @return True if the scheme is supported.
    function isFeeSchemeSupported(T.Scheme scheme) external pure returns (bool) {
        // support only FLAT scheme
        return scheme == T.Scheme.FLAT;
    }

    /// @notice Retrieves the current expiration period for enrollments or registrations.
    function getExpirationPeriod() external view returns (uint256) {
        return _expirationPeriod;
    }

    /// @notice Retrieves the enrollment deadline for a custodian.
    /// @param custodian The address of the custodian.
    function getEnrollmentDeadline(address custodian) external view returns (uint256) {
        return _enrollmentDeadline[custodian];
    }

    /// @notice Retrieves the total number of enrollments.
    function getEnrollmentCount() external view returns (uint256) {
        return _enrollmentsCount;
    }

    /// @notice Checks if the entity is active.
    /// @dev This function verifies the active status of the custodian.
    /// @param custodian The custodian's address to check.
    function isActive(address custodian) external view returns (bool) {
        // TODO a renovation mechanism is needed to update the enrollment time
        /// It ensures that custodians remain engaged and do not become inactive for extended periods.
        /// The enrollment deadline enforces a time-based mechanism where custodians must renew
        /// their registration to maintain their active status. This prevents dormant custodians
        /// from continuing to benefit from the protocol without contributing.

        // TODO add stateful management to custodians contract, the custodian can
        // change his state to "maintenance mode" or "inactive" if its facing issues
        // in that way the custodian is omitted during load balancing.
        // in this line we can check if the custodian contract is active custodian.isActive()
        // this is important feature if the custodians want to avoid harm reputation

        // This mechanism helps to verify the availability of the custodian,
        // forcing recurrent registrations and ensuring ongoing participation.
        bool notExpiredDeadline = _enrollmentDeadline[custodian] > block.timestamp;
        return _status(uint160(custodian)) == T.Status.Active && notExpiredDeadline;
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

    /// @notice Registers a custodian by sending a payment to the contract.
    /// @param proof The unique identifier of the agreement to be enforced.
    /// @param custodian The address of the custodian to register.
    function register(uint256 proof, address custodian) external onlyValidCustodian(custodian) {
        /// TODO penalize invalid endpoints, and revoked during referendum
        // !IMPORTANT:
        // Fees act as a mechanism to prevent abuse or spam by users
        // when submitting custodians for approval. This discourages users from
        // making frivolous or excessive registrations without genuine intent.
        //
        // Additionally, the fees establish a foundation of real interest and commitment
        // from the custodian. This ensures that only those who see value in the protocol
        // and are willing to contribute to its ecosystem will participate.
        //
        // The collected fees are used to support the protocol's operations, aligning
        // individual actions with the broader sustainability of the network.
        // !IMPORTANT If tollgate does not support the currency, will revert..
        T.Agreement memory agreement = AGREEMENT_SETTLER.settleAgreement(proof, msg.sender);
        if (agreement.parties[0] != custodian) {
            revert CustodianAgreementMismatch(custodian);
        }

        // register custodian as pending approval
        _register(uint160(custodian));
        // set the custodian active enrollment period..
        // after this time the custodian is considered inactive and cannot collect his profits...
        _enrollmentDeadline[custodian] = block.timestamp + _expirationPeriod;
        emit Registered(custodian, agreement.fees);
    }

    /// @notice Approves a custodian's registration.
    /// @param custodian The address of the custodian to approve.
    function approve(address custodian) external restricted {
        _enrollmentsCount++;
        _approve(uint160(custodian));
        emit Approved(custodian);
    }

    /// @notice Revokes the registration of a custodian.
    /// @param custodian The address of the custodian to revoke.
    function revoke(address custodian) external restricted {
        _enrollmentsCount--;
        _revoke(uint160(custodian));
        emit Revoked(custodian);
    }

    /// @notice Sets a new expiration period for an enrollment or registration.
    /// @param newPeriod The new expiration period, in seconds.
    function setExpirationPeriod(uint256 newPeriod) external restricted {
        _expirationPeriod = newPeriod;
        emit PeriodSet(newPeriod);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
