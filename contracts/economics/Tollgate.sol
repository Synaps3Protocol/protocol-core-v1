// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";

import { T } from "contracts/libraries/Types.sol";
import { C } from "contracts/libraries/Constants.sol";

/// @title Tollgate Contract
/// @dev This contract acts as a financial gateway, managing fees and the currencies allowed
/// within the platform. It ensures that only valid currencies (ERC-20 or native) are accepted
/// and provides mechanisms to set, retrieve, and validate fees for different contexts.
/// @notice The name "Tollgate" reflects the contract's role as a checkpoint that regulates
/// financial access through fees and approved currencies.
contract Tollgate is Initializable, UUPSUpgradeable, GovernableUpgradeable, ITollgate {
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes4 private constant INTERFACE_ID_ERC20 = type(IERC20).interfaceId;
    mapping(T.Context => EnumerableSet.AddressSet) private registeredCurrencies;
    mapping(address => mapping(T.Context => uint256)) private currencyFees;

    /// @notice Emitted when fees are set.
    /// @param fee The amount of fees being set.
    /// @param currency The currency of the fees being set.
    /// @param setBy The address that set the fees.
    event FeesSet(uint256 fee, T.Context ctx, address indexed currency, address indexed setBy);
    /// @notice Error to be thrown when an unsupported currency is used.
    /// @param currency The address of the unsupported currency.
    error InvalidUnsupportedCurrency(address currency);
    /// @notice Error thrown when trying to operate with an unsupported currency.
    /// @param currency The address of the unsupported currency.
    error InvalidCurrency(address currency);

    /// @notice Modifier to ensure only valid ERC20 or native coins are used.
    /// @param currency The address of the currency to check.
    modifier onlyValidCurrency(address currency) {
        // if not native coin then should be a valid erc20 token
        if (currency != address(0) && !currency.supportsInterface(INTERFACE_ID_ERC20)) revert InvalidCurrency(currency);
        _;
    }

    /// @dev Constructor that disables initializers to prevent the implementation contract from being initialized.
    /// @notice This constructor prevents the implementation contract from being initialized.
    /// @dev See https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
    /// @dev See https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract. Should be called only once.
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
    }

    /// @notice Returns the list of supported currencies for a given context.
    /// @param ctx The context under which the currencies are being queried.
    /// @return An array of addresses of the supported currencies for the specified context.
    function supportedCurrencies(T.Context ctx) public view returns (address[] memory) {
        // https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet-values-struct-EnumerableSet-AddressSet-
        // This operation will copy the entire storage to memory, which can be quite expensive.
        // This is designed to mostly be used by view accessors that are queried without any gas fees.
        // Developers should keep in mind that this function has an unbounded cost,
        /// and using it as part of a state-changing function may render the function uncallable
        /// if the set grows to a point where copying to memory consumes too much gas to fit in a block.
        return registeredCurrencies[ctx].values();
    }

    /// @notice Checks if a currency is supported for a given context.
    /// @param ctx The context under which the currency is being checked.
    /// @param currency The address of the currency to check.
    /// @return True if the currency is supported for the specified context, otherwise False.
    function isCurrencySupported(T.Context ctx, address currency) public view returns (bool) {
        return registeredCurrencies[ctx].contains(currency);
    }

    /// @notice Retrieves the fees for a specified context and currency.
    /// @param ctx The context for which to retrieve the fees.
    /// @param currency The address of the currency for which to retrieve the fees.
    /// @return uint256 The fees for the specified context and currency.
    function getFees(T.Context ctx, address currency) public view returns (uint256) {
        if (!isCurrencySupported(ctx, currency)) revert InvalidUnsupportedCurrency(currency);
        return currencyFees[currency][ctx];
    }

    /// @notice Sets a new fee for a specific context and currency.
    /// @param ctx The context for which the new fee is being set (e.g., registration, access).
    /// @param fee The new fee to set (can be flat fee or basis points depending on the context).
    /// @param currency The currency associated with the fee (can be ERC-20 or native currency).
    /// @dev Only the governance account can call this function to set or update fees.
    function setFees(T.Context ctx, uint256 fee, address currency) external onlyGov onlyValidCurrency(currency) {
        if (isCurrencySupported(ctx, currency)) return;
        registeredCurrencies[ctx].add(currency);
        currencyFees[currency][ctx] = fee;
        emit FeesSet(fee, ctx, currency, msg.sender);
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param newImplementation The address of the new implementation contract.
    /// @dev See https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable-_authorizeUpgrade-address-
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
