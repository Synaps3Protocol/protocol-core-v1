// SPDX-License-Identifier: MIT
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
import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { ITreasury } from "@synaps3/core/interfaces/economics/ITreasury.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";
import { IDistributor } from "@synaps3/core/interfaces/syndication/IDistributor.sol";
import { IDistributorReferendum } from "@synaps3/core/interfaces/syndication/IDistributorReferendum.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

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

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITollgate public immutable TOLLGATE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITreasury public immutable TREASURY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILedgerVault public immutable VAULT;

    uint256 private _expirationPeriod; // Period for enrollment
    uint256 private _enrollmentsCount; // Count of enrollments
    mapping(address => uint256) private _enrollmentDeadline; // Timestamp for enrollment periods
    bytes4 private constant INTERFACE_ID_DISTRIBUTOR = type(IDistributor).interfaceId;

    /// @notice Event emitted when a distributor is registered
    /// @param distributor The address of the registered distributor
    /// @param timestamp The timestamp indicating when the distributor was registered
    /// @param paidFees The amount of fees that were paid upon registration
    event Registered(address indexed distributor, uint256 timestamp, uint256 paidFees);

    /// @notice Event emitted when a distributor is approved
    /// @param distributor The address of the approved distributor
    /// @param timestamp The timestamp indicating when the distributor was approved
    event Approved(address indexed distributor, uint256 timestamp);

    /// @notice Event emitted when a distributor is revoked
    /// @param distributor The address of the revoked distributor
    /// @param timestamp The timestamp indicating when the distributor was revoked
    event Revoked(address indexed distributor, uint256 timestamp);

    /// @notice Emitted when a new period is set
    /// @param setBy The address that set the new period
    /// @param newPeriod The new period that is set, could be in seconds, blocks, or any other unit
    event PeriodSet(address indexed setBy, uint256 newPeriod);

    /// @notice Error thrown when a distributor contract is invalid
    /// @param invalid The address of the distributor contract that is invalid
    error InvalidDistributorContract(address invalid);

    /// @notice Modifier to ensure that the given distributor contract supports the IDistributor interface.
    /// @param distributor The distributor contract address.
    modifier onlyValidDistributor(address distributor) {
        if (!distributor.supportsInterface(INTERFACE_ID_DISTRIBUTOR)) {
            revert InvalidDistributorContract(distributor);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address treasury, address tollgate, address vault) {
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        _disableInitializers();
        VAULT = ILedgerVault(vault);
        TREASURY = ITreasury(treasury);
        TOLLGATE = ITollgate(tollgate);
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

    /// @notice Sets a new expiration period for an enrollment or registration.
    /// @param newPeriod The new expiration period, in seconds.
    function setExpirationPeriod(uint256 newPeriod) external restricted {
        _expirationPeriod = newPeriod;
        emit PeriodSet(msg.sender, newPeriod);
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
        // !IMPORTANT If fees manager does not support the currency, will revert..
        uint256 fees = TOLLGATE.getFees(T.Context.SYN, currency);
        VAULT.lock(msg.sender, fees, currency); // lock funds for distributor
        VAULT.claim(msg.sender, fees, currency); // claim the funds on behalf referendum
        VAULT.withdraw(address(this), fees, currency); // transfer the funds to referendum

        // register distributor as pending approval
        _register(uint160(distributor));
        // set the distributor active enrollment period..
        // after this time the distributor is considered inactive and cannot collect his profits...
        _enrollmentDeadline[distributor] = block.timestamp + _expirationPeriod;
        emit Registered(distributor, block.timestamp, fees);
    }

    /// @notice Revokes the registration of a distributor.
    /// @param distributor The address of the distributor to revoke.
    function revoke(address distributor) external restricted onlyValidDistributor(distributor) {
        _enrollmentsCount--;
        _revoke(uint160(distributor));
        emit Revoked(distributor, block.timestamp);
    }

    /// @notice Approves a distributor's registration.
    /// @param distributor The address of the distributor to approve.
    function approve(address distributor) external restricted onlyValidDistributor(distributor) {
        _enrollmentsCount++;
        _approve(uint160(distributor));
        emit Approved(distributor, block.timestamp);
    }

    /// @notice Retrieves the current expiration period for enrollments or registrations.
    function getExpirationPeriod() public view returns (uint256) {
        return _expirationPeriod;
    }

    /// @notice Retrieves the enrollment deadline for a distributor.
    /// @param distributor The address of the distributor.
    function getEnrollmentDeadline(address distributor) public view returns (uint256) {
        return _enrollmentDeadline[distributor];
    }

    /// @notice Retrieves the total number of enrollments.
    function getEnrollmentCount() external view returns (uint256) {
        return _enrollmentsCount;
    }

    /// @notice Checks if the entity is active.
    /// @dev This function verifies the active status of the distributor.
    /// @param distributor The distributor's address to check.
    function isActive(address distributor) public view onlyValidDistributor(distributor) returns (bool) {
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
    function isWaiting(address distributor) public view onlyValidDistributor(distributor) returns (bool) {
        return _status(uint160(distributor)) == Status.Waiting;
    }

    /// @notice Checks if the entity is blocked.
    /// @dev This function verifies the blocked status of the distributor.
    /// @param distributor The distributor's address to check.
    function isBlocked(address distributor) public view onlyValidDistributor(distributor) returns (bool) {
        return _status(uint160(distributor)) == Status.Blocked;
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
