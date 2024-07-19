// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "contracts/base/upgradeable/GovernableUpgradeable.sol";
import "contracts/base/upgradeable/QuorumUpgradeable.sol";
import "contracts/base/upgradeable/TreasurerUpgradeable.sol";
import "contracts/base/upgradeable/TreasuryUpgradeable.sol";

import "contracts/interfaces/IDistributor.sol";
import "contracts/interfaces/ISyndicatable.sol";
import "contracts/libraries/TreasuryHelper.sol";
import "contracts/libraries/MathHelper.sol";

/// @title Content Syndication contract.
/// @notice Use this contract to handle all distribution logic needed for creators and distributors.
/// @dev This contract uses the UUPS upgradeable pattern and AccessControl for role-based access control.
contract Syndication is
    Initializable,
    ISyndicatable,
    UUPSUpgradeable,
    GovernableUpgradeable,
    ReentrancyGuardUpgradeable,
    QuorumUpgradeable,
    TreasurerUpgradeable,
    TreasuryUpgradeable
{
    using MathHelper for uint256;
    using ERC165Checker for address;
    using TreasuryHelper for address;

    // 10% initial quitting penalization rate
    uint256 private penaltyRate = 10; // 1000 bps = 100000000000000000
    address private immutable __self = address(this);
    mapping(address => uint256) private enrollmentFees;
    
    bytes4 private constant INTERFACE_ID_IDISTRIBUTOR =
        type(IDistributor).interfaceId;

    /// @notice Error to be thrown when a distributor contract is invalid.
    error InvalidPenaltyRate();
    error InvalidDistributorContract();
    error FailDuringEnrollment(string reason);
    error FailDuringQuit(string reason);

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @notice This constructor prevents the implementation contract from being initialized.
    /// @dev See https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680 and https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
    constructor() {
        _disableInitializers();
    }

    /// @notice Modifier to ensure that the given distributor contract supports the IDistributor interface.
    /// @param distributor The distributor contract address.
    modifier validContractOnly(address distributor) {
        if (!distributor.supportsInterface(INTERFACE_ID_IDISTRIBUTOR))
            revert InvalidDistributorContract();
        _;
    }

    /// @notice Initializes the contract with the given enrollment fee and treasury address.
    /// @param initialFee The initial fee for enrollment.
    /// @param initialTreasuryAddress The initial address of the treasury.
    /// @dev This function is called only once during the contract deployment.
    function initialize(
        uint256 initialFee,
        address initialTreasuryAddress
    ) public initializer {
        __Quorum_init();
        __Governable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Treasurer_init(initialTreasuryAddress);
        __Treasury_init(initialFee, address(0));
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyAdmin {}

    /// @notice Function to set the penalty rate for quitting enrollment.
    /// @param newPenaltyRate The new penalty rate to be set. It should be a uint256 value representing a percentage (e.g., 100000000000000000 for 10%).
    /// @dev The penalty rate is a percentage (expressed as a uint256) that will be applied to the enrollment fee when a distributor quits.
    function setPenaltyRate(uint256 newPenaltyRate) public onlyGov {
        if (newPenaltyRate == 0) revert InvalidPenaltyRate();
        penaltyRate = newPenaltyRate;
    }

    /// @inheritdoc ITreasury
    /// @notice Sets a new treasury fee.
    /// @param newTreasuryFee The new treasury fee to be set.
    function setTreasuryFee(uint256 newTreasuryFee) public onlyGov {
        _setTreasuryFee(newTreasuryFee, address(0));
    }

    /// @notice Sets the address of the treasury.
    /// @param newTreasuryAddress The new treasury address to be set.
    /// @dev Only callable by the governance role.
    function setTreasuryAddress(address newTreasuryAddress) public onlyGov {
        _setTreasuryAddress(newTreasuryAddress);
    }

    /// @notice Collects funds from the contract and sends them to the treasury.
    /// @dev Only callable by an admin.
    function collectFunds() public onlyAdmin {
        // collect native token and send it to treasury
        address treasure = getTreasuryAddress();
        treasure.disburst(__self.balance);
    }

    /// @inheritdoc IRegistrable
    /// @notice Registers a distributor by sending a payment to the contract.
    /// @param distributor The address of the distributor to register.
    function register(
        address distributor
    ) public payable validContractOnly(distributor) {
        if (msg.value < getTreasuryFee(address(0)))
            revert FailDuringEnrollment("Invalid fee amount");

        // the contract manager;
        address manager = IDistributor(distributor).getManager();
        // Attempt to send the amount to the syndication contract
        __self.deposit(msg.value);
        // Persist the enrollment payment in case the distributor quits before approval
        enrollmentFees[manager] = msg.value;
        // Set the distributor as pending approval
        _register(uint160(distributor));
    }

    /**
     * @notice Checks if the entity is active.
     * @param distributor The distributor's address.
     * @return bool True if the entity is active, false otherwise.
     */
    function isActive(
        address distributor
    ) public view validContractOnly(distributor) returns (bool) {
        return _status(uint160(distributor)) == Status.Active;
    }

    /// @inheritdoc IRegistrableRevokable
    /// @notice Allows a distributor to quit and receive a penalized refund.
    /// @param distributor The address of the distributor to quit.
    /// @dev The function reverts if the distributor has not enrolled or if the refund fails.
    function quit(
        address distributor
    ) public nonReentrant validContractOnly(distributor) {
        address manager = IDistributor(distributor).getManager(); // the contract manager
        uint256 registeredAmount = enrollmentFees[manager]; // Wei
        if (registeredAmount == 0)
            revert FailDuringQuit("Invalid distributor enrollment.");

        // eg: (100 * bps) / BPS_MAX
        uint256 penal = registeredAmount.perOf(penaltyRate.calcBps());
        uint256 res = registeredAmount - penal;

        enrollmentFees[manager] = 0;
        manager.disburst(res);
        _quit(uint160(distributor));
    }

    /// @inheritdoc IRegistrableRevokable
    /// @notice Revokes the registration of a distributor.
    /// @param distributor The address of the distributor to revoke.
    function revoke(
        address distributor
    ) public onlyGov validContractOnly(distributor) {
        _revoke(uint160(distributor));
    }

    /// @inheritdoc IRegistrable
    /// @notice Approves a distributor's registration.
    /// @param distributor The address of the distributor to approve.
    function approve(
        address distributor
    ) public onlyGov validContractOnly(distributor) {
        enrollmentFees[IDistributor(distributor).getManager()] = 0;
        _approve(uint160(distributor));
    }

    /// @inheritdoc ITreasury
    /// @notice Sets a new treasury fee for a specific token.
    /// @param newTreasuryFee The new treasury fee to be set.
    /// @param token The address of the token.
    function setTreasuryFee(
        uint256 newTreasuryFee,
        address token
    ) public override onlyGov {}

    /// @notice Collects funds of a specific token from the contract and sends them to the treasury.
    /// @param token The address of the token.
    /// @dev Only callable by an admin.
    function collectFunds(address token) public onlyAdmin {}
}