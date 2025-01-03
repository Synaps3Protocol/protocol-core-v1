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

import { ILedgerVault } from "@synaps3/core/interfaces/financial/ILedgerVault.sol";
import { IAgreementManager } from "@synaps3/core/interfaces/financial/IAgreementManager.sol";
import { IAgreementSettler } from "@synaps3/core/interfaces/financial/IAgreementSettler.sol";
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
    IAgreementSettler
{
    using FeesOps for uint256;
    using FinancialOps for address;
    using EnumerableSet for EnumerableSet.UintSet;

    /// KIM: any initialization here is ephimeral and not included in bytecode..
    /// so the code within a logic contract’s constructor or global declaration
    /// will never be executed in the context of the proxy’s state
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#the-constructor-caveat

    ITreasury public immutable TREASURY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAgreementManager public immutable AGREEMENT_MANAGER;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILedgerVault public immutable VAULT;

    /// @dev Holds a the list of closed/settled proof for accounts.
    mapping(uint256 => bool) private _settledProofs;

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
        if (_settledProofs[proof]) {
            revert InvalidAgreementOp("Invalid settled agreement.");
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address treasury, address agreementManager, address vault) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        VAULT = ILedgerVault(vault);
        TREASURY = ITreasury(treasury);
        AGREEMENT_MANAGER = IAgreementManager(agreementManager);
    }

    /// Initialize the proxy state.
    function initialize(address accessManager) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlled_init(accessManager);
        __FeesCollector_init(address(TREASURY));
        __ReentrancyGuardTransient_init();
    }

    // TODO add hook management for royalties and earning splits
    // TODOpotential improvement to scaling custom actions in protocol using hooks
    // eg: access handling for gating content. etc..
    // function isAccessAllowed(bytes calldata criteria) external view return (bool) {
    //  // get registered access hooks for this contract
    //  IHook hook = HOOKS.get(address(this), IAccessHook) <- internal handling of any logic needed
    //  to get the valid hook

    //  if (!hook) return false // need conf hook
    //  return hook.exec(criteria)
    //}

    /// @notice Allows the initiator to quit the agreement and receive the committed funds.
    /// @param proof The unique identifier of the agreement.
    function quitAgreement(uint256 proof) external onlyValidAgreement(proof) nonReentrant returns (T.Agreement memory) {
        T.Agreement memory agreement = AGREEMENT_MANAGER.getAgreement(proof);
        if (agreement.initiator != msg.sender) {
            revert InvalidAgreementOp("Only initiator can quit the agreement.");
        }

        // IMPORTANT:
        // The protocol enforces a penalty for quitting the agreement to ensure fairness
        // and discourage frivolous cancellations. This mechanism protects the integrity
        // of the agreement process and ensures that resources spent in its creation
        // (e.g., computation, storage, and fee management) are compensated.
        //
        // Fees are immutable and determined at the time of agreement creation
        // (as defined in `previewAgreement`).This design disincentives manipulation,
        // ensuring that no changes can occur later to unfairly benefit or harm the initiator or other parties involved.

        //
        // Penalty fees retained here also help maintain the protocol's economic balance
        // and ensure that the system operates sustainably over time.
        uint256 fees = agreement.fees; // keep fees as penalty
        uint256 available = agreement.total - fees; // initiator rollback
        address initiator = agreement.initiator; // the original initiator
        address currency = agreement.currency;

        _setProofAsSettled(proof);
        // part of the agreement locked amount is released to the account
        VAULT.claim(initiator, fees, currency);
        VAULT.release(initiator, available, currency);
        VAULT.withdraw(address(this), fees, currency);
        emit AgreementCancelled(initiator, proof);
        return agreement;
    }

    /// @notice Settles an agreement by marking it inactive and transferring funds to the counterparty.
    /// @param proof The unique identifier of the agreement.
    /// @param counterparty The address that will receive the funds upon settlement.
    function settleAgreement(
        uint256 proof,
        address counterparty
    ) public onlyValidAgreement(proof) returns (T.Agreement memory) {
        // retrieve the agreement to storage to inactivate it and return it
        T.Agreement memory agreement = AGREEMENT_MANAGER.getAgreement(proof);
        if (agreement.broker != msg.sender) {
            revert InvalidAgreementOp("Only broker can settle the agreement.");
        }

        uint256 total = agreement.total; // protocol
        uint256 fees = agreement.fees; // protocol
        uint256 available = total - fees; // holder earnings
        address initiator = agreement.initiator;
        address currency = agreement.currency;

        // TODO: Implement a time window to enforce the validity period for agreement settlement.
        // Once the window expires, the agreement should be marked as invalid or revert,
        // then quit is only way to close the agreement.
        _setProofAsSettled(proof);
        // move the funds to settler and transfer the available to counterparty
        VAULT.claim(initiator, total, currency);
        VAULT.transfer(counterparty, available, currency);
        VAULT.withdraw(address(this), fees, currency);
        emit AgreementSettled(msg.sender, counterparty, proof);
        return agreement;
    }

    /// @dev Authorizes the upgrade of the contract.
    /// @notice Only the owner can authorize the upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @dev Marks a proof as "settled" in the registry.
    /// @param proof The unique identifier of the proof to be settled.
    function _setProofAsSettled(uint256 proof) private {
        _settledProofs[proof] = true;
    }

    // /// @dev Distributes the amount based on the provided shares array.
    // /// @param amount The total amount to be allocated.
    // /// @param currency The address of the currency being allocated.
    // /// @param shares An array of Splits structs specifying split percentages and target addresses.
    // function _allocate(
    //     uint256 amount,
    //     address currency,
    //     T.Shares[] memory shares
    // ) private returns (uint256) {
    //     // If there is no distribution, return the full amount.
    //     if (shares.length == 0) return amount;
    //     if (shares.length > 100) {
    //         revert NoDeal(
    //             "Invalid split allocations. Cannot exceed 100."
    //         );
    //     }

    //     uint8 i = 0;
    //     uint256 accBps = 0; // Accumulated base points.
    //     uint256 accTotal = 0; // Accumulated total allocation.

    //     while (i < shares.length) {
    //         // Retrieve base points and target address from the distribution array.
    //         uint256 bps = shares[i].bps;
    //         address target = shares[i].target;
    //         // Safely increment i (unchecked overflow).
    //         unchecked {
    //             ++i;
    //         }

    //         if (bps == 0) continue;
    //         // Calculate and register the allocation for each distribution.
    //         uint256 registeredAmount = amount.perOf(bps);
    //         target.transfer(registeredAmount, currency);
    //         accTotal += registeredAmount;
    //         accBps += bps;
    //     }

    //     // Ensure total base points do not exceed the maximum allowed (100%).
    //     if (accBps > C.BPS_MAX)
    //         revert NoDeal("Invalid split base points overflow.");
    //     return amount - accTotal; // Returns the remaining unallocated amount.
    // }
}
