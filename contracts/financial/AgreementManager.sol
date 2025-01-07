// SPDX-License-Identifier: MIT
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

contract AgreementManager is Initializable, UUPSUpgradeable, AccessControlledUpgradeable, IAgreementManager {
    using FeesOps for uint256;
    using FinancialOps for address;
    using EnumerableSet for EnumerableSet.UintSet;

    /// KIM: any initialization here is ephemeral and not included in bytecode..
    /// so the code within a logic contract’s constructor or global declaration
    /// will never be executed in the context of the proxy’s state
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#the-constructor-caveat

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITollgate public immutable TOLLGATE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILedgerVault public immutable VAULT;

    /// @dev Holds a bounded key expressing the agreement between the parts.
    mapping(uint256 => T.Agreement) private _agreementsByProof;

    /// @notice Emitted when an agreement is created.
    /// @param initiator The account that initiated or created the agreement.
    /// @param proof The unique identifier (hash or proof) of the created agreement.
    event AgreementCreated(address indexed initiator, uint256 proof);

    /// @dev Custom error thrown for invalid operations on an agreement, with a descriptive message.
    /// @param message A string explaining the invalid operation.
    error InvalidAgreementOp(string message);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address tollgate, address vault) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to collect the fees during the agreement creation.
        TOLLGATE = ITollgate(tollgate);
        VAULT = ILedgerVault(vault);
    }

    /// Initialize the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
    }

    /// @notice Creates and stores a new agreement.
    /// @param amount The total amount committed.
    /// @param currency The currency used for the agreement.
    /// @param broker The authorized address to manage the agreement.
    /// @param parties The parties in the agreement.
    /// @param payload Additional data for execution.
    function createAgreement(
        uint256 amount,
        address currency,
        address broker,
        address[] calldata parties,
        bytes calldata payload
    ) external returns (uint256) {
        // IMPORTANT: The process of distributing funds to accounts should be handled within the settlement logic.
        uint256 confirmed = VAULT.lock(msg.sender, amount, currency); // msg.sender.safeDeposit(amount, currency);
        T.Agreement memory agreement = previewAgreement(confirmed, currency, broker, parties, payload);
        // only the initiator can operate with this agreement proof, or transfer the proof to the other party..
        // each agreement is unique and immutable, ensuring that it cannot be modified or reconstructed.
        uint256 proof = _createAndStoreProof(agreement);
        emit AgreementCreated(msg.sender, proof);
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
    /// @param broker The authorized account to manage the agreement.
    /// @param parties The parties in the agreement.
    /// @param payload Additional data for execution.
    function previewAgreement(
        uint256 amount,
        address currency,
        address broker,
        address[] calldata parties,
        bytes calldata payload
    ) public view returns (T.Agreement memory) {
        if (parties.length == 0) {
            revert InvalidAgreementOp("Agreement must include at least one party");
        }

        // TODO Even if we are covered by gas fees, a good way to avoid abuse is penalize parties after N length
        // eg. The max parties allowed is 5, any extra parties are charged with a extra * fee

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
        uint256 deductions = _calcFees(amount, broker, currency);
        // This design ensures fairness and transparency by preventing any future
        // adjustments to fees or protocol conditions from affecting the terms of this agreement.
        return
            T.Agreement({
                broker: broker, // the authorized account to manage the agreement
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

    /// @notice Calculates the fee based on the provided total amount and currency.
    /// @dev Reverts if the currency is not supported by the fees manager.
    /// @param total The total amount from which the fee will be calculated.
    /// @param broker The address or context for which the fee applies.
    /// @param currency The address of the currency for which the fee is being calculated.
    function _calcFees(uint256 total, address broker, address currency) private view returns (uint256) {
        // The broker acts as the operational context for retrieving the applicable fee.
        if (!TOLLGATE.isSchemeSupported(T.Scheme.BPS, broker, currency)) {
            revert InvalidAgreementOp("Invalid not supported broker");
        }

        // !IMPORTANT if fees manager does not support the currency, will revert..
        uint256 fees = TOLLGATE.getFees(T.Scheme.BPS, broker, currency);
        return total.perOf(fees); // bps repr enforced by tollgate..
    }
}
