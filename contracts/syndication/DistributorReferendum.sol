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
import { TreasuryHelper } from "contracts/libraries/TreasuryHelper.sol";
import { T } from "contracts/libraries/Types.sol";

contract DistributorReferendum is
    Initializable,
    UUPSUpgradeable,
    QuorumUpgradeable,
    GovernableUpgradeable,
    ReentrancyGuardUpgradeable,
    IDistributorReferendum
{
    using TreasuryHelper for address;
    using ERC165Checker for address;

    ITollgate public tollgate;
    ITreasury public treasury;

    uint256 public enrollmentPeriod; // Period for enrollment
    uint256 public enrollmentsCount; // Count of enrollments
    mapping(address => uint256) public enrollmentTime; // Timestamp for enrollment periods
    bytes4 private constant INTERFACE_ID_IDISTRIBUTOR = type(IDistributor).interfaceId;

    /// @notice Event emitted when a distributor is registered
    /// @param distributor The address of the registered distributor
    event Registered(address indexed distributor, uint256 paidFees);
    /// @notice Event emitted when a distributor is approved
    /// @param distributor The address of the approved distributor
    event Approved(address indexed distributor);
    /// @notice Event emitted when a distributor resigns
    /// @param distributor The address of the resigned distributor
    event Resigned(address indexed distributor);
    /// @notice Event emitted when a distributor is revoked
    /// @param distributor The address of the revoked distributor
    event Revoked(address indexed distributor);
    /// @notice Emitted when a new period is set.
    /// @param newPeriod The new period that is set (in seconds, blocks, etc.).
    /// @param setBy The address that set the new period.
    event PeriodSet(uint256 newPeriod, address indexed setBy);
    /// @notice Error thrown when a distributor contract is invalid
    error InvalidDistributorContract(address invalid);

    /// @notice Modifier to ensure that the given distributor contract supports the IDistributor interface.
    /// @param distributor The distributor contract address.
    modifier withValidDistributor(address distributor) {
        if (!distributor.supportsInterface(INTERFACE_ID_IDISTRIBUTOR)) revert InvalidDistributorContract(distributor);
        _;
    }

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @notice This constructor prevents the implementation contract from being initialized.
    /// @dev See https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
    /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the given multimedia coin (MMC), treasury, enrollment fee, and initial penalty rate.
    /// @param treasury_ The address of the treasury contract, which manages fund handling and storage for the platform.
    /// @param tollgate_ The address of the tollgate contract, responsible for fee and currency management.
    function initialize(address treasury_, address tollgate_) public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
        __ReentrancyGuard_init();
        treasury = ITreasury(treasury_);
        tollgate = ITollgate(tollgate_);
        // 6 months initially..
        enrollmentPeriod = 180 days;
    }

    /// @notice Sets a new expiration period for an enrollment or registration.
    /// @param newPeriod The new expiration period, in seconds.
    function setExpirationPeriod(uint256 newPeriod) external onlyGov {
        enrollmentPeriod = newPeriod;
        emit PeriodSet(newPeriod, msg.sender);
    }

    /// @notice Disburses funds from the contract to a specified address.
    /// @param currency The address of the ERC20 token to disburse tokens.
    /// @dev This function can only be called by governance or an authorized entity.
    function disburse(address currency) external onlyGov nonReentrant {
        // transfer all the funds to the treasury..
        uint256 amount = address(this).balanceOf(currency);
        address target = treasury.getPoolAddress();
        target.transfer(amount, currency); // sent amount to vault..
        emit FeesDisbursed(target, amount, currency);
    }

    /// @notice Registers a distributor by sending a payment to the contract.
    /// @param distributor The address of the distributor to register.
    /// @param currency The currency used to pay enrollment.
    function register(address distributor, address currency) external payable withValidDistributor(distributor) {
        // !IMPORTANT if fees manager does not support the currency, will revert..
        uint256 fees = tollgate.getFees(T.Context.SYN, currency);
        uint256 total = msg.sender.safeDeposit(fees, currency);
        // set the distributor active enrollment period..
        // after this time the distributor is considered inactive and cannot collect his profits...
        enrollmentTime[distributor] = block.timestamp + enrollmentPeriod;
        // Set the distributor as pending approval
        _register(uint160(distributor));
        emit Registered(distributor, total);
    }

    /// @notice Revokes the registration of a distributor.
    /// @param distributor The address of the distributor to revoke.
    function revoke(address distributor) external onlyGov withValidDistributor(distributor) {
        enrollmentsCount--;
        _revoke(uint160(distributor));
        emit Revoked(distributor);
    }

    /// @notice Approves a distributor's registration.
    /// @param distributor The address of the distributor to approve.
    function approve(address distributor) external onlyGov withValidDistributor(distributor) {
        // reset ledger..
        enrollmentsCount++;
        _approve(uint160(distributor));
        emit Approved(distributor);
    }

    /// @notice Retrieves the current expiration period for enrollments or registrations.
    /// @return The expiration period, in seconds.
    function getExpirationPeriod() public view returns (uint256) {
        return enrollmentPeriod;
    }

    /// @notice Retrieves the enrollment time for a distributor, taking into account the current block time and the expiration period.
    /// @param distributor The address of the distributor.
    /// @return The enrollment time in seconds.
    function getEnrollmentTime(address distributor) public view returns (uint256) {
        return enrollmentTime[distributor];
    }

    /// @notice Retrieves the total number of enrollments.
    /// @return The count of enrollments.
    function getEnrollmentCount() external view returns (uint256) {
        return enrollmentsCount;
    }

    /// @notice Checks if the entity is active.
    /// @dev This function verifies the active status of the distributor.
    /// @param distributor The distributor's address to check.
    /// @return bool True if the distributor is active, false otherwise.
    function isActive(address distributor) public view withValidDistributor(distributor) returns (bool) {
        // this mechanisms helps to verify the availability of the distributor forcing recurrent registrations and status verification.
        return _status(uint160(distributor)) == Status.Active && enrollmentTime[distributor] > block.timestamp;
    }

    /// @notice Checks if the entity is waiting.
    /// @dev This function verifies the waiting status of the distributor.
    /// @param distributor The distributor's address to check.
    /// @return bool True if the distributor is waiting, false otherwise.
    function isWaiting(address distributor) public view withValidDistributor(distributor) returns (bool) {
        return _status(uint160(distributor)) == Status.Waiting;
    }

    /// @notice Checks if the entity is blocked.
    /// @dev This function verifies the blocked status of the distributor.
    /// @param distributor The distributor's address to check.
    /// @return bool True if the distributor is blocked, false otherwise.
    function isBlocked(address distributor) public view withValidDistributor(distributor) returns (bool) {
        return _status(uint160(distributor)) == Status.Blocked;
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
