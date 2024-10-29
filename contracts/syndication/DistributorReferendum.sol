// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { QuorumUpgradeable } from "contracts/base/upgradeable/QuorumUpgradeable.sol";

import { ITreasury } from "contracts/interfaces/economics/ITreasury.sol";
import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";
import { IDistributor } from "contracts/interfaces/syndication/IDistributor.sol";
import { IDistributorReferendum } from "contracts/interfaces/syndication/IDistributorReferendum.sol";
import { TreasuryOps } from "contracts/libraries/TreasuryOps.sol";
import { T } from "contracts/libraries/Types.sol";

contract DistributorReferendum is
    Initializable,
    UUPSUpgradeable,
    QuorumUpgradeable,
    GovernableUpgradeable,
    ReentrancyGuardUpgradeable,
    IDistributorReferendum
{
    using TreasuryOps for address;
    using ERC165Checker for address;

    /// Preventing accidental/malicious changes during contract reinitializations.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITollgate public immutable TOLLGATE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITreasury public immutable TREASURY;

    uint256 private enrollmentPeriod; // Period for enrollment
    uint256 private enrollmentsCount; // Count of enrollments
    mapping(address => uint256) private enrollmentDeadline; // Timestamp for enrollment periods
    bytes4 private constant INTERFACE_ID_IDISTRIBUTOR = type(IDistributor).interfaceId;

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
        if (!distributor.supportsInterface(INTERFACE_ID_IDISTRIBUTOR)) {
            revert InvalidDistributorContract(distributor);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address treasury, address tollgate) {
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        _disableInitializers();
        TREASURY = ITreasury(treasury);
        TOLLGATE = ITollgate(tollgate);
    }

    /// @notice Initializes the proxy state.
    function initialize() public initializer {
        __Quorum_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Governable_init(msg.sender);

        // 6 months initially..
        enrollmentPeriod = 180 days;
    }

    /// @notice Sets a new expiration period for an enrollment or registration.
    /// @param newPeriod The new expiration period, in seconds.
    function setExpirationPeriod(uint256 newPeriod) external onlyGov {
        enrollmentPeriod = newPeriod;
        emit PeriodSet(msg.sender, newPeriod);
    }

    /// @notice Disburses funds from the contract to a specified address.
    /// @param currency The address of the ERC20 token to disburse tokens.
    /// @dev This function can only be called by governance or an authorized entity.
    function disburse(address currency) external onlyGov nonReentrant {
        // transfer all the funds to the treasury..
        uint256 amount = address(this).balanceOf(currency);
        address target = TREASURY.getPoolAddress();
        target.transfer(amount, currency); // sent amount to vault..
        emit FeesDisbursed(target, amount, currency);
    }

    /// @notice Registers a distributor by sending a payment to the contract.
    /// @param distributor The address of the distributor to register.
    /// @param currency The currency used to pay enrollment.
    function register(address distributor, address currency) external payable onlyValidDistributor(distributor) {
        // !IMPORTANT if fees manager does not support the currency, will revert..
        uint256 fees = TOLLGATE.getFees(T.Context.SYN, currency);
        uint256 total = msg.sender.safeDeposit(fees, currency);
        // Set the distributor as pending approval
        _register(uint160(distributor));
        // set the distributor active enrollment period..
        // after this time the distributor is considered inactive and cannot collect his profits...
        enrollmentDeadline[distributor] = block.timestamp + enrollmentPeriod;
        emit Registered(distributor, block.timestamp, total);
    }

    /// @notice Revokes the registration of a distributor.
    /// @param distributor The address of the distributor to revoke.
    function revoke(address distributor) external onlyGov onlyValidDistributor(distributor) {
        enrollmentsCount--;
        _revoke(uint160(distributor));
        emit Revoked(distributor, block.timestamp);
    }

    /// @notice Approves a distributor's registration.
    /// @param distributor The address of the distributor to approve.
    function approve(address distributor) external onlyGov onlyValidDistributor(distributor) {
        // reset ledger..
        enrollmentsCount++;
        _approve(uint160(distributor));
        emit Approved(distributor, block.timestamp);
    }

    /// @notice Retrieves the current expiration period for enrollments or registrations.
    function getExpirationPeriod() public view returns (uint256) {
        return enrollmentPeriod;
    }

    /// @notice Retrieves the enrollment deadline for a distributor.
    /// @param distributor The address of the distributor.
    function getEnrollmentDeadline(address distributor) public view returns (uint256) {
        return enrollmentDeadline[distributor];
    }

    /// @notice Retrieves the total number of enrollments.
    function getEnrollmentCount() external view returns (uint256) {
        return enrollmentsCount;
    }

    /// @notice Checks if the entity is active.
    /// @dev This function verifies the active status of the distributor.
    /// @param distributor The distributor's address to check.
    function isActive(address distributor) public view onlyValidDistributor(distributor) returns (bool) {
        // TODO a renovation mechanism is needed to update the enrollment time
        // this mechanisms helps to verify the availability of the distributor forcing recurrent registrations.
        return _status(uint160(distributor)) == Status.Active && enrollmentDeadline[distributor] > block.timestamp;
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
