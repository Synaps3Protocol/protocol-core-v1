// TODO payment splitter
// TODO aca se puede tener un metodo que collecte todos los fees
// https://docs.openzeppelin.com/contracts/4.x/api/finance#PaymentSplitter

// el settler toma el agreement desde agreement
// TODO el settlement podria tener split conf por ejemplo
// TODO

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

contract AgreementSettler is
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

    /// @dev Holds a bounded key expressing the agreement between the parts.
    mapping(uint256 => T.Agreement) private _agreementsByProof;
    /// @dev Holds a the list of actives proof for accounts.
    mapping(address => EnumerableSet.UintSet) private _activeProofs;

    /// @notice Emitted when an agreement is settled by the designated broker or authorized account.
    /// @param broker The account that facilitated the agreement settlement.
    /// @param proof The unique identifier (hash or proof) of the settled agreement.
    event AgreementSettled(address indexed broker, address indexed counterparty, uint256 proof);

    /// @notice Emitted when an agreement is canceled by the broker or another authorized account.
    /// @param initiator The account that initiated the cancellation.
    /// @param proof The unique identifier (hash or proof) of the canceled agreement.
    event AgreementCancelled(address indexed initiator, uint256 proof);

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

    /// @notice Allows the initiator to quit the agreement and receive the committed funds.
    /// @param proof The unique identifier of the agreement.
    function quitAgreement(uint256 proof) external onlyValidAgreement(proof) nonReentrant returns (T.Agreement memory) {
        T.Agreement memory agreement = getAgreement(proof);
        if (agreement.initiator != msg.sender) {
            revert InvalidAgreementOp("Only initiator can close the agreement.");
        }

        // a partial rollback amount is registered in treasury..
        uint256 available = agreement.available; // initiator rollback
        address initiator = agreement.initiator; // the original initiator
        uint256 fees = agreement.fees; // keep fees as penalty
        address currency = agreement.currency;
        _closeAgreement(proof); // close the agreement
        _sumLedgerEntry(address(this), fees, currency);
        _registerFundsInTreasury(initiator, available, currency);
        emit AgreementCancelled(initiator, proof);
        return agreement;
    }

        // TODO aca se registran los closed y en agreement los open y genera paralelismo y continuidad..
    /// @notice Retrieves the list of active proofs associated with a specific account.
    /// @param account The address of the account whose active proofs are being queried.
    function getClosedProofs(address account) public view returns (uint256[] memory) {
        return _activeProofs[account].values();
    }

    /// @notice Settles an agreement by marking it inactive and transferring funds to the counterparty.
    /// @param proof The unique identifier of the agreement.
    /// @param counterparty The address that will receive the funds upon settlement.
    function settleAgreement(
        uint256 proof,
        address counterparty
    ) public onlyValidAgreement(proof) returns (T.Agreement memory) {
        // retrieve the agreement to storage to inactivate it and return it
        T.Agreement memory agreement = getAgreement(proof);
        if (agreement.broker != msg.sender) {
            revert InvalidAgreementOp("Only broker can settle the agreement.");
        }

        uint256 fees = agreement.fees; // protocol
        uint256 available = agreement.available; // holder earnings
        address currency = agreement.currency;
        _closeAgreement(proof); // after settled the agreement is complete..
        _sumLedgerEntry(address(this), fees, currency);
        _registerFundsInTreasury(counterparty, available, currency);
        emit AgreementSettled(msg.sender, counterparty, proof);
        return agreement;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

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

    /// @notice Registers a specified amount of currency in the treasury on behalf of the recipient.
    /// @dev This function increases the allowance for the treasury to access the specified `amount` of `currency`
    ///      and then deposits the funds into the treasury for the given `recipient`.
    /// @param recipient The address that will receive the registered funds in the treasury.
    /// @param amount The amount of currency to be registered in the treasury.
    /// @param currency The address of the ERC20 token used for the registration, or `address(0)` for native currency.
    function _registerFundsInTreasury(address recipient, uint256 amount, address currency) private {
        // during the closing of the deal the earnings are registered in treasury..
        address(TREASURY).increaseAllowance(amount, currency);
        // TODO deposit a ledger vault
        TREASURY.deposit(recipient, amount, currency);
    }
}
