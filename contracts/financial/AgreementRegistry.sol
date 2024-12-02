// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlledUpgradeable } from "@synaps3/core/primitives/upgradeable/AccessControlledUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardTransientUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { FeesCollectorUpgradeable } from "@synaps3/core/primitives/upgradeable/FeesCollectorUpgradeable.sol";

import { IRightsAccessAgreement } from "@synaps3/core/interfaces/rights/IRightsAccessAgreement.sol";
import { ITollgate } from "@synaps3/core/interfaces/economics/ITollgate.sol";
import { ITreasury } from "@synaps3/core/interfaces/economics/ITreasury.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";
import { FeesOps } from "@synaps3/core/libraries/FeesOps.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

contract AgreementRegistry is
    Initializable,
    UUPSUpgradeable,
    AccessControlledUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    FeesCollectorUpgradeable,
    IRightsAccessAgreement
{
    using FeesOps for uint256;
    using FinancialOps for address;
    using EnumerableSet for EnumerableSet.UintSet;

    /// KIM: any initialization here is ephimeral and not included in bytecode..
    /// so the code within a logic contract’s constructor or global declaration
    /// will never be executed in the context of the proxy’s state
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#the-constructor-caveat

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITreasury public immutable TREASURY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITollgate public immutable TOLLGATE;

    /// @dev Holds a bounded key expressing the agreement between the parts.
    mapping(uint256 => T.Agreement) private _agreementsByProof;

    /// @notice Emitted when an agreement is created.
    /// @param initiator The account that initiated or created the agreement.
    /// @param proof The unique identifier (hash or proof) of the created agreement.
    event AgreementCreated(address indexed initiator, uint256 proof);

    /// @dev Custom error thrown for invalid operations on an agreement, with a descriptive message.
    /// @param message A string explaining the invalid operation.
    error InvalidAgreementOp(string message);

    /// @notice Ensures the agreement associated with the provided `proof` is valid and active.
    modifier onlyValidAgreement(uint256 proof) {
        T.Agreement memory agreement = getAgreement(proof);
        bool isActiveProof = _activeProofs[agreement.initiator].contains(proof);
        if (agreement.initiator == address(0) || !isActiveProof) {
            revert InvalidAgreementOp("Invalid inactive agreement.");
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address treasury, address tollgate) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to collect the fees during the agreement creation.
        TOLLGATE = ITollgate(tollgate);
        TREASURY = ITreasury(treasury);
    }

    /// Initialize the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
        __FeesCollector_init(address(TREASURY));
        __ReentrancyGuardTransient_init();
    }

    /// @notice Creates and stores a new agreement.
    /// @param amount The total amount committed.
    /// @param currency The currency used for the agreement.
    /// @param broker The authorized account to manage the agreement.
    /// @param parties The parties in the agreement.
    /// @param payload Additional data for execution.
    function createAgreement(
        uint256 amount,
        address currency,
        address broker,
        address[] calldata parties,
        bytes calldata payload
    ) external returns (uint256) {
        // IMPORTANT: The process of distributing funds to accounts should be handled within the policy logic.
        uint256 confirmed = msg.sender.safeDeposit(amount, currency);
        T.Agreement memory agreement = previewAgreement(confirmed, currency, broker, parties, payload);
        // only the initiator can operate with this agreement proof, or transfer the proof to the other party..
        // each agreement is unique and immutable, ensuring that it cannot be modified or reconstructed.
        uint256 proof = _createProof(agreement);
        _storeAgreement(proof, agreement);
        emit AgreementCreated(msg.sender, proof);
        return proof;
    }

    /// @notice Retrieves the list of active proofs associated with a specific account.
    /// @param account The address of the account whose active proofs are being queried.
    function getActiveProofs(address account) public view returns (uint256[] memory) {
        return _activeProofs[account].values();
    }

    /// @notice Retrieves the details of an agreement based on the provided proof.
    /// @param proof The unique identifier (hash) of the agreement.
    function getAgreement(uint256 proof) public view returns (T.Agreement memory) {
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

        // agreements transport value..
        // imagine an agreement like a bonus, gift card, prepaid card or check..
        uint256 deductions = _calcFees(amount, currency);
        uint256 available = amount - deductions; // the total after fees
        // this design protects the agreement's terms from any future changes in fees or protocol conditions.
        // by using this immutable approach, the agreement terms are "frozen" at the time of creation.
        return
            T.Agreement({
                broker: broker, // the authorized account to manage the agreement
                currency: currency, // the currency used in transaction
                initiator: msg.sender, // the tx initiator
                amount: amount, // the transaction amount
                fees: deductions, // the protocol fees of the agreement
                available: available, // the remaining amount after fees
                createdAt: block.timestamp, // the agreement creation time
                parties: parties, // the accounts related to agreement
                payload: payload // any additional data needed during agreement execution
            });
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @dev Generates a unique proof for an agreement using keccak256 hashing.
    function _createProof(T.Agreement memory agreement) private pure returns (uint256) {
        // yes, we can encode full struct as abi.encode with extra overhead..
        bytes memory rawProof = abi.encode(agreement);
        bytes32 proof = keccak256(rawProof);
        return uint256(proof);
    }

    /// @dev Set the agreement relation with proof in storage.
    function _storeAgreement(uint256 proof, T.Agreement memory agreement) private {
        _agreementsByProof[proof] = agreement; // store agreement..
        _activeProofs[agreement.initiator].add(proof);
    }

    /// @dev Marks an agreement as inactive, effectively closing it.
    function _closeAgreement(uint256 proof) private returns (T.Agreement storage) {
        // retrieve the agreement to storage to inactivate it and return it
        T.Agreement storage agreement = _agreementsByProof[proof];
        _activeProofs[agreement.initiator].remove(proof);
        return agreement;
    }

    /// @notice Calculates the fee based on the provided total amount and currency.
    /// @dev Reverts if the currency is not supported by the fees manager.
    /// @param total The total amount from which the fee will be calculated.
    /// @param currency The address of the currency for which the fee is being calculated.
    function _calcFees(uint256 total, address currency) private view returns (uint256) {
        //!IMPORTANT if fees manager does not support the currency, will revert..
        uint256 fees = TOLLGATE.getFees(T.Context.RMA, currency);
        return total.perOf(fees); // bps repr enforced by tollgate..
    }
}
