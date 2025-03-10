// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { FeesCollectorUpgradeable } from "@synaps3/core/primitives/upgradeable/FeesCollectorUpgradeable.sol";
import { QuorumUpgradeable } from "@synaps3/core/primitives/upgradeable/QuorumUpgradeable.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";
import { ITreasury } from "@synaps3/core/interfaces/economics/ITreasury.sol";
import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { IDistributor } from "@synaps3/core/interfaces/syndication/IDistributor.sol";
import { IDistributorReferendum } from "@synaps3/core/interfaces/syndication/IDistributorReferendum.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @title DistributorReferendum
/// @notice Manages the registration, approval, and revocation of content distributors.
/// @dev Implements `IDistributorReferendum` and ensures that only valid distributors can operate.
///      This contract integrates with `LedgerVault` for financial management, `Tollgate` for fee validation,
///      and `Treasury` for protocol-wide economic operations.
contract DistributorReferendum is
    Initializable,
    UUPSUpgradeable,
    QuorumUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    FeesCollectorUpgradeable,
    IDistributorReferendum
{
    using FinancialOps for address;
    using ERC165Checker for address;

    /// @dev Stores the interface ID for IDistributor, ensuring compatibility verification.
    bytes4 private constant INTERFACE_ID_DISTRIBUTOR = type(IDistributor).interfaceId;

    ///Our immutables behave as constants after deployment
    //slither-disable-start naming-convention
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITollgate public immutable TOLLGATE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITreasury public immutable TREASURY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILedgerVault public immutable LEDGER_VAULT;
    //slither-disable-end naming-convention

    /// @dev Defines the expiration period for enrollment, determining how long a distributor remains active.
    uint256 private _expirationPeriod;
    /// @dev Tracks the number of active enrollments within the system.
    uint256 private _enrollmentsCount;
    /// @dev Maps a distributor's address to their respective enrollment deadline timestamp.
    mapping(address => uint256) private _enrollmentDeadline;

    /// @notice Event emitted when a distributor is registered
    /// @param distributor The address of the registered distributor
    /// @param paidFees The amount of fees that were paid upon registration
    event Registered(address indexed distributor, uint256 paidFees);

    /// @notice Event emitted when a distributor is approved
    /// @param distributor The address of the approved distributor
    event Approved(address indexed distributor);

    /// @notice Event emitted when a distributor is revoked
    /// @param distributor The address of the revoked distributor
    event Revoked(address indexed distributor);

    /// @notice Emitted when a new period is set
    /// @param newPeriod The new period that is set, could be in seconds, blocks, or any other unit
    event PeriodSet(uint256 newPeriod);

    /// @notice Error thrown when a distributor contract is invalid
    /// @param invalid The address of the distributor contract that is invalid
    error InvalidDistributorContract(address invalid);

    /// @notice Error thrown when an invalid fee scheme is provided for a referendum operation.
    /// @param message A descriptive message explaining the reason for the invalid fee scheme.
    error InvalidFeeSchemeProvided(string message);

    /// @notice Modifier to ensure that the given distributor contract supports the IDistributor interface.
    /// @param distributor The distributor contract address.
    modifier onlyValidDistributor(address distributor) {
        if (!distributor.supportsInterface(INTERFACE_ID_DISTRIBUTOR)) {
            revert InvalidDistributorContract(distributor);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address treasury, address tollgate, address ledgerVault) {
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        _disableInitializers();
        TREASURY = ITreasury(treasury);
        TOLLGATE = ITollgate(tollgate);
        LEDGER_VAULT = ILedgerVault(ledgerVault);
    }

    /// @notice Initializes the proxy state.
    function initialize(address accessManager) public initializer {
        __Quorum_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuardTransient_init();
        __AccessControlled_init(accessManager);
        __FeesCollector_init(address(TREASURY));
        // 6 months initially..
        _expirationPeriod = 180 days;
    }

    /// @notice Retrieves the current expiration period for enrollments or registrations.
    function getExpirationPeriod() external view returns (uint256) {
        return _expirationPeriod;
    }

    /// @notice Retrieves the enrollment deadline for a distributor.
    /// @param distributor The address of the distributor.
    function getEnrollmentDeadline(address distributor) external view returns (uint256) {
        return _enrollmentDeadline[distributor];
    }

    /// @notice Retrieves the total number of enrollments.
    function getEnrollmentCount() external view returns (uint256) {
        return _enrollmentsCount;
    }

    /// @notice Checks if the entity is active.
    /// @dev This function verifies the active status of the distributor.
    /// @param distributor The distributor's address to check.
    function isActive(address distributor) external view onlyValidDistributor(distributor) returns (bool) {
        // TODO a renovation mechanism is needed to update the enrollment time
        /// It ensures that distributors remain engaged and do not become inactive for extended periods.
        /// The enrollment deadline enforces a time-based mechanism where distributors must renew
        /// their registration to maintain their active status. This prevents dormant distributors
        /// from continuing to benefit from the protocol without contributing.

        // This mechanism helps to verify the availability of the distributor,
        // forcing recurrent registrations and ensuring ongoing participation.
        bool notExpiredDeadline = _enrollmentDeadline[distributor] > block.timestamp;
        return _status(uint160(distributor)) == Status.Active && notExpiredDeadline;
    }

    /// @notice Checks if the entity is waiting.
    /// @dev This function verifies the waiting status of the distributor.
    /// @param distributor The distributor's address to check.
    function isWaiting(address distributor) external view onlyValidDistributor(distributor) returns (bool) {
        return _status(uint160(distributor)) == Status.Waiting;
    }

    /// @notice Checks if the entity is blocked.
    /// @dev This function verifies the blocked status of the distributor.
    /// @param distributor The distributor's address to check.
    function isBlocked(address distributor) external view onlyValidDistributor(distributor) returns (bool) {
        return _status(uint160(distributor)) == Status.Blocked;
    }

    /// @notice Registers a distributor by sending a payment to the contract.
    /// @param distributor The address of the distributor to register.
    /// @param currency The currency used to pay enrollment.
    function register(address distributor, address currency) external onlyValidDistributor(distributor) {
        // !IMPORTANT:
        // Fees act as a mechanism to prevent abuse or spam by users
        // when submitting distributors for approval. This discourages users from
        // making frivolous or excessive registrations without genuine intent.
        //
        // Additionally, the fees establish a foundation of real interest and commitment
        // from the distributor. This ensures that only those who see value in the protocol
        // and are willing to contribute to its ecosystem will participate.
        //
        // The collected fees are used to support the protocol's operations, aligning
        // individual actions with the broader sustainability of the network.
        // !IMPORTANT If tollgate does not support the currency, will revert..
        (uint256 fees, T.Scheme scheme) = TOLLGATE.getFees(address(this), currency);
        if (scheme != T.Scheme.FLAT) revert InvalidFeeSchemeProvided("Expected a FLAT fee scheme.");

        // TODO: additional check if exists in factory to validate emission
        // eg: distribution.getCreator MUST be equal to msg.sender
        uint256 locked = LEDGER_VAULT.lock(msg.sender, fees, currency); // lock funds
        uint256 claimed = LEDGER_VAULT.claim(msg.sender, locked, currency); // claim the funds on behalf
        uint256 confirmed = LEDGER_VAULT.withdraw(address(this), claimed, currency); // collect funds
        // register distributor as pending approval
        _register(uint160(distributor));
        // set the distributor active enrollment period..
        // after this time the distributor is considered inactive and cannot collect his profits...
        _enrollmentDeadline[distributor] = block.timestamp + _expirationPeriod;
        emit Registered(distributor, confirmed);
    }

    /// @notice Approves a distributor's registration.
    /// @param distributor The address of the distributor to approve.
    function approve(address distributor) external restricted onlyValidDistributor(distributor) {
        _enrollmentsCount++;
        _approve(uint160(distributor));
        emit Approved(distributor);
    }

    /// @notice Revokes the registration of a distributor.
    /// @param distributor The address of the distributor to revoke.
    function revoke(address distributor) external restricted onlyValidDistributor(distributor) {
        _enrollmentsCount--;
        _revoke(uint160(distributor));
        emit Revoked(distributor);
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
