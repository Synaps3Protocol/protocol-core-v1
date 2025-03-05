// SPDX-License-Identifier: BUSL-1.1
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

/// @title AgreementSettler
/// @notice Manages the finalization of agreements (trustless escrow system), handling fund distribution and settlement.
/// @dev This contract ensures fair settlements, enforces penalties for agreement cancellations,
///      and collects protocol fees. It interacts with the Treasury, LedgerVault, and AgreementManager
///      to properly allocate locked funds upon agreement resolution.
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

    /// KIM: any initialization here is ephemeral and not included in bytecode..
    /// so the code within a logic contract’s constructor or global declaration
    /// will never be executed in the context of the proxy’s state
    /// https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#the-constructor-caveat

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// Our immutables behave as constants after deployment
    //slither-disable-start naming-convention
    ITreasury public immutable TREASURY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAgreementManager public immutable AGREEMENT_MANAGER;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILedgerVault public immutable LEDGER_VAULT;
    //slither-disable-end naming-convention

    /// @dev Holds a the list of closed/settled proof for accounts.
    mapping(uint256 => bool) private _settledProofs;

    /// @notice Emitted when an agreement is settled by the designated agent or authorized account.
    /// @param arbiter The designated escrow agent enforcing the agreement settlement.
    /// @param counterparty The address that received the settlement funds.
    /// @param proof The unique identifier (hash or proof) of the settled agreement.
    /// @param collectedFees The amount of fees collected from the settlement process.
    event AgreementSettled(address indexed arbiter, address indexed counterparty, uint256 proof, uint256 collectedFees);

    /// @notice Emitted when an agreement is canceled by the authorized account.
    /// @param initiator The account that initiated the cancellation.
    /// @param proof The unique identifier (hash or proof) of the canceled agreement.
    /// @param collectedFees The amount of fees collected (if any) upon cancellation.
    event AgreementCancelled(address indexed initiator, uint256 proof, uint256 collectedFees);

    /// @notice Error thrown when the agreement proof has already been settled.
    error AgreementAlreadySettled();

    /// @dev Error thrown when settlement fails due to incorrect fee extraction.
    error SettlementFailed(uint256 extracted, uint256 expectedFees);

    /// @notice Error thrown when the caller is not authorized to settle the agreement.
    error UnauthorizedEscrowAgent();

    /// @notice Error thrown when the initiator is not authorized to quit the agreement.
    error UnauthorizedInitiator();

    /// @notice Ensures the agreement associated with the provided `proof` is valid and active.
    modifier onlyValidAgreement(uint256 proof) {
        if (_settledProofs[proof]) {
            revert AgreementAlreadySettled();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address treasury, address agreementManager, address ledgerVault) {
        /// https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680
        /// https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/5
        _disableInitializers();
        TREASURY = ITreasury(treasury);
        LEDGER_VAULT = ILedgerVault(ledgerVault);
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
        if (agreement.initiator != msg.sender) revert UnauthorizedInitiator();

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
        // slither-disable-start unused-return
        // part of the agreement locked amount is released to the account
        LEDGER_VAULT.claim(initiator, fees, currency);
        LEDGER_VAULT.release(initiator, available, currency);
        LEDGER_VAULT.withdraw(address(this), fees, currency);
        // slither-disable-end unused-return
        emit AgreementCancelled(initiator, proof, fees);
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
        if (agreement.arbiter != msg.sender) revert UnauthorizedEscrowAgent();

        uint256 total = agreement.total; // protocol
        uint256 fees = agreement.fees; // protocol
        uint256 available = total - fees; // holder earnings
        address initiator = agreement.initiator;
        address currency = agreement.currency;
        // TODO: Implement a time window to enforce the validity period for agreement settlement.
        // Once the window expires, the agreement should be marked as invalid or revert,
        // then quit is only way to close the agreement.
        _setProofAsSettled(proof);

        // slither-disable-start unused-return
        // move the funds to settler and transfer the available to counterparty
        LEDGER_VAULT.claim(initiator, total, currency);
        LEDGER_VAULT.transfer(counterparty, available, currency);
        LEDGER_VAULT.withdraw(address(this), fees, currency);
        // slither-disable-end unused-return

        emit AgreementSettled(msg.sender, counterparty, proof, fees);
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
