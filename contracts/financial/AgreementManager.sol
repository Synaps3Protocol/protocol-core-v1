// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";

import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { IAgreementManager } from "@synaps3/core/interfaces/financial/IAgreementManager.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { FeesOps } from "@synaps3/core/libraries/FeesOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

// TODO Doc: Trustless escrow system - modular escrow framework - escrow mechanism (agreement <arbitrer> settlement)

/// @title AgreementManager
/// @notice Manages the lifecycle (trustless escrow system) of agreements, including creation and retrieval.
/// @dev This contract ensures that agreements are immutable upon creation, enforcing fair and transparent terms.
///      It integrates with `LedgerVault` for fund management and `Tollgate` for fee validation.
contract AgreementManager is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IAgreementManager {
    using FeesOps for uint256;
    using FinancialOps for address;
    using EnumerableSet for EnumerableSet.UintSet;

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
    error UnsupportedAgreementCurrency(address target, address currency);

    /// @notice Error thrown when an agreement includes no parties.
    error NoPartiesInAgreement();

    /// @notice Ensures that the specified currency is supported for the given target.
    /// @dev This modifier verifies if the `currency` is accepted under the context of `target`.
    ///      If the currency is not supported, it reverts with `UnsupportedCurrency(target, currency)`.
    /// @param target The address or context that requires currency validation.
    /// @param currency The address of the currency being checked.
    modifier onlySupportedCurrency(address target, address currency) {
        bool isCurrencySupported = TOLLGATE.isSupportedCurrency(target, currency);
        if (!isCurrencySupported) revert UnsupportedAgreementCurrency(target, currency);
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
        uint256 confirmed = LEDGER_VAULT.lock(msg.sender, amount, currency);
        T.Agreement memory agreement = previewAgreement(confirmed, currency, arbiter, parties, payload);
        // only the initiator can operate with this agreement proof, or transfer the proof to the other party..
        // each agreement is unique and immutable, ensuring that it cannot be modified or reconstructed.
        uint256 proof = _createAndStoreProof(agreement);
        emit AgreementCreated(msg.sender, proof, amount, currency);
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
        if (parties.length == 0) {
            revert NoPartiesInAgreement();
        }

        // TODO Even if we are covered by gas fees, during execution a good way to avoid abuse
        // is penalize parties after N length eg. The max parties allowed is 5, any extra
        // parties are charged with a extra * fee. Denial of Service risk

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
        uint256 deductions = _calcFees(amount, arbiter, currency);
        // This design ensures fairness and transparency by preventing any future
        // adjustments to fees or protocol conditions from affecting the terms of this agreement.
        return
            T.Agreement({
                arbiter: arbiter, // the authorized account to enforce the agreement
                currency: currency, // the currency used in transaction
                initiator: msg.sender, // the tx initiator
                total: amount, // the transaction amount
                fees: deductions, // the protocol fees of the agreement
                parties: parties, // the accounts related to agreement
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

    /// @notice Calculates the fee based on the provided total amount, agent, and currency.
    /// @dev Reverts if the currency is not supported by the Tollgate or if no fee scheme is defined for the agent.
    /// @param total The total amount from which the fee will be calculated.
    /// @param target The address or context (e.g., agreement or service) for which the fee applies.
    /// @param currency The address of the currency for which the fee is being calculated.
    /// @return The calculated fee amount based on the applicable fee scheme.
    function _calcFees(uint256 total, address target, address currency) private view returns (uint256) {
        // !IMPORTANT if fees manager does not support the currency, will revert..
        (uint256 fees, T.Scheme scheme) = TOLLGATE.getFees(target, currency);
        if (scheme == T.Scheme.BPS) return total.perOf(fees); // bps calc
        if (scheme == T.Scheme.NOMINAL) return total.perOf(fees.calcBps()); // nominal to bps
        if (total < fees) revert FlatFeeExceedsTotal(total, fees); // if flat fee
        return fees; // ok flat fee is safe
    }
}
