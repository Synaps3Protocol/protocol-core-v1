// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";

import { T } from "@synaps3/core/primitives/Types.sol";
import { FeesOps } from "@synaps3/core/libraries/FeesOps.sol";

/// @title Tollgate Contract
/// @notice Manages fees and approved currencies for various operations within the protocol.
/// @dev This contract ensures proper fee validation and currency registration for different operational contexts.
contract Tollgate is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, ITollgate {
    using FeesOps for uint256;
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev ERC-20 interface ID used to validate token compliance.
    bytes4 private constant INTERFACE_ID_ERC20 = type(IERC20).interfaceId;
    /// @dev Tracks registered currencies for specific targets.
    /// Uses EnumerableSet for efficient storage and querying of currency addresses.
    mapping(address => EnumerableSet.AddressSet) private _registeredCurrencies;
    /// @dev Stores fees associated with specific target and currencies..
    mapping(bytes32 => uint256) private _currencyFees;

    /// @notice Emitted when fees are set or updated.
    /// @param target The address or context where the fee applies.
    /// @param currency The currency associated with the fee.
    /// @param setBy The address that set the fee.
    /// @param scheme The fee representation scheme (flat, nominal, or basis points).
    /// @param fee The value of the fee being set.
    event FeesSet(
        address indexed target,
        address indexed currency,
        address indexed setBy,
        T.Scheme scheme,
        uint256 fee
    );

    /// @notice Error for unsupported currencies.
    /// @param currency The address of the unsupported currency.
    error InvalidUnsupportedCurrency(address currency);

    /// @notice Error invalid unsupported context.
    error InvalidTargetContext();

    /// @notice Error for invalid basis point fees.
    /// @param bps The provided basis point value.
    error InvalidBasisPointRange(uint256 bps);

    /// @notice Error for invalid nominal fees.
    /// @param nominal The provided nominal fee value.
    error InvalidNominalRange(uint256 nominal);

    /// @notice Ensures the validity of fee representation based on the selected scheme.
    /// @param scheme The fee scheme (flat, nominal, or basis points).
    /// @param fee The fee value to validate.
    modifier onlyValidFeeRepresentation(T.Scheme scheme, uint256 fee) {
        if (T.Scheme.BPS == scheme && !fee.isBasePoint()) revert InvalidBasisPointRange(fee);
        if (T.Scheme.NOMINAL == scheme && !fee.isNominal()) revert InvalidNominalRange(fee);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract state.
    /// @param accessManager The address of the access control manager.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Retrieves the list of supported currencies for a given target.
    /// @param target The address or context for which to retrieve supported currencies.
    /// @return An array of supported currency addresses.
    function supportedCurrencies(address target) public view returns (address[] memory) {
        return _registeredCurrencies[target].values();
    }

    /// @notice Checks if a fee scheme is supported for a given target and currency.
    /// @param scheme The fee representation scheme (flat, nominal, or basis points).
    /// @param target The address or context to check.
    /// @param currency The address of the currency to verify.
    /// @return `true` if the currency is supported, otherwise `false`.
    function isSchemeSupported(T.Scheme scheme, address target, address currency) public view returns (bool) {
        bytes32 composedKey = _computeComposedKey(target, currency, scheme);
        return _registeredCurrencies[target].contains(currency) && _currencyFees[composedKey] > 0;
    }

    /// @notice Retrieves the fee value for a specific target and currency.
    /// @param scheme The fee representation scheme.
    /// @param target The context or address for which to retrieve the fee.
    /// @param currency The address of the currency.
    /// @return The fee value.
    function getFees(T.Scheme scheme, address target, address currency) external view returns (uint256) {
        if (!isSchemeSupported(scheme, target, currency)) revert InvalidUnsupportedCurrency(currency);
        bytes32 composedKey = _computeComposedKey(target, currency, scheme);
        return _currencyFees[composedKey];
    }

    /// @notice Sets or updates fees for a specific target and currency.
    /// @param scheme The fee representation scheme.
    /// @param fee The new fee value.
    /// @param target The context or address for which the fee is being set.
    /// @param currency The currency associated with the fee.
    function setFees(
        T.Scheme scheme,
        address target,
        uint256 fee,
        address currency
    ) external restricted onlyValidFeeRepresentation(scheme, fee) {
        // Compute a unique composed key based on the target, currency, and scheme.
        // The composed key is used to uniquely identify a combination of these parameters
        // in a flat storage mapping. This avoids the need for nested mappings, improving gas efficiency
        // and simplifying data access.
        // Example: If the target is an agreement contract, the currency is MMC (ERC20 token),
        // and the scheme is NOMINAL, setting a fee of 10% means:
        // "In the agreement contract, for MMC, using a nominal scheme, the fee is 10%."
        if (target == address(0)) revert InvalidTargetContext();
        bytes32 composedKey = _computeComposedKey(target, currency, scheme);
        _registeredCurrencies[target].add(currency);
        _currencyFees[composedKey] = fee; // target + currency + scheme = fee
        emit FeesSet(target, currency, msg.sender, scheme, fee);
    }

    /// @notice Computes a unique key for a currency and scheme combination.
    /// @param target The target context.
    /// @param currency The currency associated with the fee.
    /// @param scheme The fee scheme.
    /// @return The computed key as a `bytes32` hash.
    function _computeComposedKey(address target, address currency, T.Scheme scheme) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(target, currency, scheme));
    }

    /// @notice Ensures only authorized accounts can upgrade the contract.
    /// @param newImplementation The address of the new contract implementation.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
