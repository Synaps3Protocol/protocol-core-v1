// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";

import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { IAgreementManager } from "@synaps3/core/interfaces/financial/IAgreementManager.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { FeesOps } from "@synaps3/core/libraries/FeesOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";
import { C } from "@synaps3/core/primitives/Constants.sol";

/// @title AgreementManager
/// @notice Manages the lifecycle (trustless escrow system) of agreements, including creation and retrieval.
/// @dev This contract ensures that agreements are immutable upon creation, enforcing fair and transparent terms.
///      It integrates with `LedgerVault` for fund management and `Tollgate` for fee validation.
contract AgreementManager is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IAgreementManager {
    using FeesOps for uint256;
    using FinancialOps for address;

    /// KIM: any initialization here is ephemeral and not included in bytecode..
    /// so the code within a logic contract’s constructor or global declaration
    /// will never be executed in the context of the proxy’s state
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#the-constructor-caveat

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// Our immutables behave as constants after deployment
    //slither-disable-start naming-convention
    ITollgate public immutable TOLLGATE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILedgerVault public immutable LEDGER_VAULT;
    //slither-disable-end naming-convention

    /// @notice Maximum allowed number of parties per agreement.
    /// @dev Can be updated by admin to adapt system limits.
    uint256 private _maxParties;
    /// @dev Holds a bounded key expressing the agreement between the parts.
    mapping(uint256 => T.Agreement) private _agreementsByProof;

    /// @notice Emitted when a new agreement is successfully created.
    /// @param initiator The address of the account that initiated or created the agreement.
    /// @param proof A unique identifier (hash or proof) representing the created agreement.
    /// @param amount The monetary amount specified in the agreement.
    /// @param currency The address of the token used as currency in the agreement.
    event AgreementCreated(address indexed initiator, uint256 indexed proof, uint256 amount, address currency);

    /// @notice Error thrown when a flat fee exceeds the total amount.
    error FlatFeeExceedsTotal(uint256 total, uint256 fee);

    /// @notice Error thrown when a currency is not supported by the specified target.
    /// @param target The address or context for which the currency is unsupported.
    /// @param currency The address of the unsupported currency.
    error UnsupportedAgreementTarget(address target, address currency);

    /// @notice Error thrown when trying to set an invalid maximum number of parties.
    error InvalidMaxParties(uint256 value);

    /// @notice Error thrown when the number of parties exceeds the protocol limit.
    error ExceedsMaxParties();

    /// @notice Ensures that the specified currency is supported for the given target.
    /// @dev This modifier verifies if the `currency` is accepted under the context of `target`.
    ///      If the currency is not supported, it reverts with `UnsupportedCurrency(target, currency)`.
    /// @param target The address or context that requires currency validation.
    /// @param currency The address of the currency being checked.
    modifier onlySupportedCurrency(address target, address currency) {
        bool isCurrencySupported = TOLLGATE.isSupportedCurrency(target, currency);
        if (!isCurrencySupported) revert UnsupportedAgreementTarget(target, currency);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address tollgate, address ledgerVault) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to collect the fees during the agreement creation.
        TOLLGATE = ITollgate(tollgate);
        LEDGER_VAULT = ILedgerVault(ledgerVault);
    }

    /// Initialize the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
        _maxParties = 5;
    }

    /// @notice Updates the maximum number of allowed parties.
    /// @param newMax The new maximum number of parties.
    function setMaxParties(uint256 newMax) external onlyAdmin {
        if (newMax == 0) revert InvalidMaxParties(newMax);
        _maxParties = newMax;
    }

    /// @notice Retrieves the current max number of parties.
    function maxParties() external view returns (uint256) {
        return _maxParties;
    }

    /// @notice Creates and stores a new agreement.
    /// @param amount The total amount committed.
    /// @param currency The currency used for the agreement.
    /// @param arbiter The designated escrow agent enforcing the agreement.
    /// @param parties The parties in the agreement.
    /// @param payload Additional data for execution.
    function createAgreement(
        uint256 amount,
        address currency,
        address arbiter,
        address[] calldata parties,
        bytes calldata payload
    ) external onlySupportedCurrency(arbiter, currency) returns (uint256) {
        // IMPORTANT: The process of distributing funds to accounts should be handled within the settlement logic.
        T.Agreement memory agreement = previewAgreement(amount, currency, arbiter, parties, payload);
        uint256 confirmed = LEDGER_VAULT.lock(msg.sender, agreement.locked, currency);

        // only the initiator can operate with this agreement proof, or transfer the proof to the other party..
        // each agreement is unique and immutable, ensuring that it cannot be modified or reconstructed.
        uint256 proof = _createAndStoreProof(agreement);
        emit AgreementCreated(msg.sender, proof, confirmed, currency);
        return proof;
    }

    /// @notice Retrieves the details of an agreement based on the provided proof.
    /// @param proof The unique identifier (hash) of the agreement.
    function getAgreement(uint256 proof) external view returns (T.Agreement memory) {
        return _agreementsByProof[proof];
    }

    /// @notice Previews an agreement by calculating fees and returning the agreement terms without committing them.
    /// @param amount The total amount committed.
    /// @param currency The currency used for the agreement.
    /// @param arbiter The designated escrow agent enforcing the agreement.
    /// @param parties The parties in the agreement.
    /// @param payload Additional data for execution.
    function previewAgreement(
        uint256 amount,
        address currency,
        address arbiter,
        address[] calldata parties,
        bytes calldata payload
    ) public view onlySupportedCurrency(arbiter, currency) returns (T.Agreement memory) {
        // IMPORTANT:
        // Agreements transport value and represent a defined commitment between parties.
        // Think of an agreement as similar to a bonus, gift card, prepaid card, or check:
        // its value and terms are fixed at creation and cannot be changed arbitrarily.

        // Fees are calculated during this preview and "frozen" into the agreement terms.
        // This ensures that the fee structure at the time of agreement creation remains
        // immutable and protects all parties from potential future manipulations.
        //
        // By locking in fees during agreement creation, the protocol avoids scenarios
        // where fee structures change (favorably or unfavorably) after creation,
        // which could lead to abuse or exploitation.
        uint256 baseFees = _calcFees(amount, arbiter, currency);
        // Even if we are covered by gas fees, during execution a good way to avoid abuse
        // is penalize parties after N length eg. The initial max parties allowed is 5, any extra
        // parties are charged with an extra. Denial of Service risk mitigation..
        uint256 penalization = _calculatePenalization(parties.length, amount);
        uint256 totalToLock = amount + penalization;

        // This design ensures fairness and transparency by preventing any future
        // adjustments to fees or protocol conditions from affecting the terms of this agreement.
        return
            T.Agreement({
                arbiter: arbiter, // the authorized account to enforce the agreement
                currency: currency, // the currency used in transaction
                initiator: msg.sender, // the tx initiator
                total: amount, // the transaction amount
                fees: baseFees, // the protocol fees of the agreement
                locked: totalToLock, // the total to lock, may contain penalization
                parties: parties, // the additional accounts related to agreement 1:N agreement
                payload: payload // any additional data needed during agreement execution
            });
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @dev Generates a unique proof for an agreement using keccak256 hashing.
    function _createAndStoreProof(T.Agreement memory agreement) private returns (uint256) {
        // yes, we can encode full struct as abi.encode with extra overhead..
        bytes memory rawProof = abi.encode(agreement, block.number, address(this));
        uint256 proof = uint256(keccak256(rawProof));
        _agreementsByProof[proof] = agreement;
        return proof;
    }

    /// @dev Calculates the penalization based on parties len and total amount
    function _calculatePenalization(uint256 partiesLen, uint256 amount) private view returns (uint256 penalization) {
        if (partiesLen <= _maxParties) return 0;
        uint256 excess = partiesLen - _maxParties;
        uint256 multiplierBps = _penaltyBps(excess);
        penalization = amount.perOf(multiplierBps);
    }

    /// @dev Computes the penalty BPS as a arithmetic succession.
    ///      1st extra = 1%, 2nd extra = +2%, 3rd extra = +3%, ...
    ///      Formula: (N * (N + 1) / 2) * 100
    /// @param excess Number of parties beyond the allowed max.
    /// @return penaltyBps Total penalty in basis points.
    function _penaltyBps(uint256 excess) private pure returns (uint256 penaltyBps) {
        if (excess == 0) return 0;
        // Formula for the sum of an arithmetic succession: S = n(n + 1) / 2
        // Example: excess = 3 -> 1 + 2 + 3 = 6 %
        unchecked {
            penaltyBps = ((excess * (excess + 1)) / 2) * 100;
        }

        // strict hard cap revert if bps > 10_0000
        if (penaltyBps > C.BPS_MAX) {
            revert ExceedsMaxParties();
        }
    }

    /// @notice Calculates the fee based on the provided total amount, agent, and currency.
    /// @dev Reverts if the currency is not supported by the Tollgate or if no fee scheme is defined for the agent.
    /// @param total The total amount from which the fee will be calculated.
    /// @param target The address or context (e.g., agreement or service) for which the fee applies.
    /// @param currency The address of the currency for which the fee is being calculated.
    /// @return The calculated fee amount based on the applicable fee scheme.
    function _calcFees(uint256 total, address target, address currency) private view returns (uint256) {
        // !IMPORTANT if fees manager does not support the currency or the target, will revert..
        (uint256 fees, T.Scheme scheme) = TOLLGATE.getFees(target, currency);
        if (scheme == T.Scheme.BPS) return total.perOf(fees); // bps calc
        if (scheme == T.Scheme.NOMINAL) return total.perOf(fees.calcBps()); // nominal to bps
        if (total < fees) revert FlatFeeExceedsTotal(total, fees); // if flat fee
        return fees; // ok flat fee is safe
    }
}
