// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
import { IFeeSchemeValidator } from "@synaps3/core/interfaces/economics/IFeeSchemeValidator.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";

import { T } from "@synaps3/core/primitives/Types.sol";
import { FeesOps } from "@synaps3/core/libraries/FeesOps.sol";

/// @title Tollgate
/// @notice Manages fees and approved currencies for various operations within the protocol.
/// @dev This contract ensures proper fee validation and currency registration for different operational contexts.
contract Tollgate is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, ITollgate {
    using FeesOps for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// Note: Mappings do not benefit from storage packing, as each mapping entry
    ///       is stored in a separate slot, making reordering inconsequential for packing efficiency.
    /// @dev Tracks registered currencies for specific targets.
    /// Uses EnumerableSet for efficient storage and querying of currency addresses.
    mapping(address => EnumerableSet.AddressSet) private _registeredCurrencies;
    /// @dev Stores fees associated with specific target and currencies..
    mapping(bytes32 => uint256) private _currencyFees;
    /// @dev Stores the target supported schema.
    mapping(address => T.Scheme) private _targetScheme;

    /// @notice Emitted when fees are set or updated.
    /// @param target The address or context where the fee applies.
    /// @param currency The currency associated with the fee.
    /// @param scheme The fee representation scheme (flat, nominal, or basis points).
    /// @param fee The value of the fee being set.
    event FeesSet(address indexed target, address indexed currency, T.Scheme scheme, uint256 fee);

    /// @notice Error for unsupported currencies.
    /// @param target The context where the currency is unsupported.
    /// @param currency The address of the unsupported currency.
    error UnsupportedCurrency(address target, address currency);

    /// @notice Error for invalid target contexts.
    /// @param target The address of the invalid target context.
    error InvalidTargetContext(address target);

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

    /// @notice Allows execution if the scheme is accepted or if support cannot be determined.
    /// @dev This modifier checks whether the `target` contract explicitly supports the scheme via `isSupported`.
    /// If `isSupported` exists and returns `false`, the call is reverted with InvalidTargetContext.
    /// If the call to `isSupported` fails (e.g., target does not implement the function or reverts), execution is allowed by default.
    /// This enables compatibility with contracts that do not implement scheme validation.
    /// @param scheme The scheme to validate.
    /// @param target The address of the contract expected to support the scheme.
    modifier onlyIfFeeSchemeSupported(T.Scheme scheme, address target) {
        try IFeeSchemeValidator(target).isFeeSchemeSupported(scheme) returns (bool ok) {
            if (!ok) revert InvalidTargetContext(target);
            _;
        } catch {
            // by default all schemes are allowed
            _;
        }
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

    /// @notice Returns true if currency is supported by target.
    /// @param target The context or address for which to verify supported currencies.
    /// @param currency The address of the currency to check.
    /// @return True if the currency is supported, false otherwise.
    function isSupportedCurrency(address target, address currency) external view returns (bool) {
        return _isSchemeSupported(target, currency);
    }

    /// @notice Retrieves the list of supported currencies for a given target.
    /// @param target The address or context for which to retrieve supported currencies.
    /// @return An array of supported currency addresses.
    function supportedCurrencies(address target) external view returns (address[] memory) {
        return _registeredCurrencies[target].values();
    }

    /// @notice Retrieves the fee value for a specific target and currency.
    /// @param target The context or address for which to retrieve the fee.
    /// @param currency The address of the currency.
    /// @return The fee value.
    function getFees(address target, address currency) external view returns (uint256, T.Scheme) {
        // if scheme is supported return the fee and scheme
        if (!_isSchemeSupported(target, currency)) {
            revert UnsupportedCurrency(target, currency);
        }

        T.Scheme scheme = _targetScheme[target];
        bytes32 composedKey = _computeComposedKey(target, currency, scheme);
        uint256 fee = _currencyFees[composedKey];
        return (fee, scheme);
    }

    /// @notice Sets or updates fees for a specific target and currency.
    /// @param scheme The fee representation scheme.
    /// @param fee The new fee value to associate with target.
    /// @param target The context or address for which the fee is being set.
    /// @param currency The currency associated with the fee.
    function setFees(
        T.Scheme scheme,
        address target,
        uint256 fee,
        address currency
    ) external onlyIfFeeSchemeSupported(scheme, target) onlyValidFeeRepresentation(scheme, fee) restricted {
        // Compute a unique composed key based on the target, currency, and scheme.
        // The composed key uniquely identifies a deterministic combination of these parameters
        // in a flat storage mapping. This avoids nested mappings, improving gas efficiency
        // and simplifying data access through deterministic association.
        // Example: If the target is the policy manager contract, the currency is MMC (ERC20 token),
        // and the scheme is NOMINAL, setting a fee of 10% means:
        // "In the policy manager contract, for MMC, using a nominal scheme, the fee is 10%."
        if (target == address(0)) revert InvalidTargetContext(target);
        bytes32 composedKey = _computeComposedKey(target, currency, scheme);

        _targetScheme[target] = scheme; // eg: rights manager => FLAT
        _currencyFees[composedKey] = fee; // target + currency + scheme = fee
        _registeredCurrencies[target].add(currency);
        emit FeesSet(target, currency, scheme, fee);
    }

    /// @notice Ensures only authorized accounts can upgrade the contract.
    /// @param newImplementation The address of the new contract implementation.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Checks if a fee scheme is supported for a given target and currency.
    /// @param target The address or context to check.
    /// @param currency The address of the currency to verify.
    /// @return `true` if the currency is supported, otherwise `false`.
    function _isSchemeSupported(address target, address currency) private view returns (bool) {
        T.Scheme scheme = _targetScheme[target];
        bytes32 composedKey = _computeComposedKey(target, currency, scheme);
        return _registeredCurrencies[target].contains(currency) && _currencyFees[composedKey] > 0;
    }

    /// @notice Computes a unique key for a currency and scheme combination.
    /// @param target The target context.
    /// @param currency The currency associated with the fee.
    /// @param scheme The fee scheme.
    /// @return The computed key as a `bytes32` hash.
    function _computeComposedKey(address target, address currency, T.Scheme scheme) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(target, currency, scheme));
    }
}
