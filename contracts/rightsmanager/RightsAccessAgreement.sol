// SPDX-License-Identifier: MIT
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { GovernableUpgradeable } from "contracts/base/upgradeable/GovernableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IRightsAccessAgreement } from "contracts/interfaces/rightsmanager/IRightsAccessAgreement.sol";
import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";
import { FeesHelper } from "contracts/libraries/FeesHelper.sol";
import { T } from "contracts/libraries/Types.sol";

contract RightsAccessAgreement is Initializable, UUPSUpgradeable, GovernableUpgradeable, IRightsAccessAgreement {
    using FeesHelper for uint256;
    /// KIM: any initialization here is ephimeral and not included in bytecode..
    /// so the code within a logic contract’s constructor or global declaration
    /// will never be executed in the context of the proxy’s state
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#the-constructor-caveat

    /// Preventing accidental/malicious changes during contract reinitializations.
    ITollgate public immutable TOLLGATE;

    // @dev Holds a bounded key expressing the agreement between the parts.
    // The key is derived using keccak256 hashing of the account and the rights holder.
    // This mapping stores active agreements, indexed by their unique proof.
    mapping(bytes32 => T.Agreement) private agreements;

    /// @notice Emitted when an agreement is created.
    /// @param proof The unique identifier (hash or proof) of the created agreement.
    event AgreementCreated(bytes32 indexed proof);
    // @notice Thrown when the provided proof is invalid.
    error InvalidAgreementProof();
    /// @dev Error thrown when a proposed agreement fails to execute.
    /// @param reason A string providing the reason for the failure.
    error NoAgreement(string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address tollgate) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        // we need to collect the fees during the agreement creation.
        TOLLGATE = ITollgate(tollgate);
    }

    /// Initialize the proxy state.
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Governable_init(msg.sender);
    }

    /// @notice Settles the agreement associated with the given proof, preparing it for payment processing.
    /// @dev This function retrieves the agreement and marks it as settled to trigger any associated payments.
    /// @param proof The unique identifier of the agreement to settle.
    function settleAgreement(bytes32 proof) external returns (T.Agreement memory) {
        if (!isValidProof(proof)) revert InvalidAgreementProof();
        _closeAgreement(proof);
        return agreements[proof];
    }

    /// @notice Creates a new agreement between the account and the content holder.
    /// @dev This function handles the creation of a new agreement by negotiating terms, calculating fees,
    /// and generating a unique proof of the agreement.
    /// @param total The total amount involved in the agreement.
    /// @param currency The address of the ERC20 token (or native currency) being used in the agreement.
    /// @param holder The address of the content holder whose content is being accessed.
    /// @param account The address of the account proposing the agreement.
    /// @param payload Additional data required to execute the agreement.
    function createAgreement(
        uint256 total,
        address currency,
        address holder,
        address account,
        bytes calldata payload
    ) public returns (bytes32) {
        uint256 deductions = _calcFees(total, currency);
        if (deductions > total) revert NoAgreement("The fees are too high.");
        uint256 available = total - deductions; // the total after fees
        // one agreement it's unique and cannot be reconstructed..
        // create a new immutable agreement to interact with register policy
        T.Agreement memory agreement = T.Agreement(
            block.timestamp, // the agreement creation time
            total, // the transaction total amount
            available, // the remaining amount after fees
            currency, // the currency used in transaction
            account, // the account related to agreement
            holder, // the content rights holder
            payload, // any additional data needed during agreement execution
            true // the agreement status, true for active, false for closed.
        );

        // keccak256(abi.encodePacked(....))
        bytes32 proof = _createProof(agreement);
        emit AgreementCreated(proof);
        return proof;
    }

    /// @notice Checks if a given proof corresponds to an active agreement.
    /// @dev Verifies the existence and active status of the agreement in storage.
    /// @param proof The unique identifier of the agreement to validate.
    function isValidProof(bytes32 proof) public view returns (bool) {
        return agreements[proof].active;
    }

    /// @notice Creates and stores a new agreement proof.
    /// @dev The proof is generated using keccak256 hashing of the agreement data.
    ///      This proof is then used as a unique identifier for the agreement in the storage.
    /// @param agreement The agreement object containing the terms and parties involved.
    function _createProof(T.Agreement memory agreement) internal returns (bytes32) {
        // yes, we can encode full struct as abi.encode with extra overhead..
        bytes32 proof = keccak256(
            abi.encodePacked(
                agreement.time,
                agreement.total,
                agreement.holder,
                agreement.account,
                agreement.currency,
                agreement.payload
            )
        );

        // activate agreement before
        agreements[proof] = agreement;
        return proof;
    }

    /// @notice Close a agreement for a given proof corresponds to an active agreement.
    /// @dev Set the status as inactive of the agreement in storage.
    /// @param proof The unique identifier of the agreement to validate.
    function _closeAgreement(bytes32 proof) internal {
        agreements[proof].active = false;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

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
