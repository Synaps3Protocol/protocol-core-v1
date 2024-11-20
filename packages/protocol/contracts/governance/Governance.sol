// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.26;

import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { GovernorVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import { GovernorSettings } from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import { GovernorCountingSimple } from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorTimelockControl } from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
// solhint-disable-next-line max-line-length
import { GovernorVotesQuorumFraction } from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

/**
 * @title Governance
 * @notice This contract implements a governance mechanism based on OpenZeppelin's Governor contract.
 * It uses an ERC20Votes token for voting, a TimelockController for queuing and executing proposals, and
 * several governance extensions for enhanced functionality.
 */
contract Governance is
    Governor,
    GovernorVotes,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    GovernorSettings,
    GovernorTimelockControl
{
    /**
     * @notice Initializes the governance contract with the specified parameters.
     * @param _mmc The ERC20Votes token contract to be used for voting.
     * @param _timelock The TimelockController contract to be used for queuing and executing proposals.
     *
     * The constructor sets up the governance contract with:
     * - Governor("MMCGovernance"): The name of the governance contract.
     * - GovernorVotes(_mmc): The ERC20 token with voting capabilities.
     * - GovernorVotesQuorumFraction(4): The quorum required is 4% of the total token supply.
     * - GovernorSettings(1, 45818, 0): Configures the governance settings:
     *   - Voting Delay: 1 block (the time that must pass between the creation of a proposal and the start of voting).
     *   - Voting Period: 45818 blocks (approximately 1 week, the period during which voting is open).
     *   - Proposal Threshold: 0 tokens (the minimum number of tokens required to propose a new proposal).
     */
    constructor(
        ERC20Votes _mmc,
        TimelockController _timelock
    )
        Governor("MMCGovernance")
        GovernorVotes(_mmc)
        GovernorVotesQuorumFraction(4)
        GovernorSettings(1 /* 1 block */, 45818 /* 1 week */, 0)
        GovernorTimelockControl(_timelock)
    {}

    /// @notice Returns the state of a proposal.
    /// @param proposalId The ID of the proposal.
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    /// @notice Checks if a proposal needs to be queued.
    /// @param proposalId The ID of the proposal.
    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view virtual override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    /**
     * @notice Queues a proposal's operations.
     * @param proposalId The ID of the proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The values (in wei) to send with the calls.
     * @param calldatas The calldata to send with the calls.
     * @param descriptionHash The hash of the proposal's description.
     * @return The timestamp at which the operations are queued.
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Executes a proposal's operations.
     * @param proposalId The ID of the proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The values (in wei) to send with the calls.
     * @param calldatas The calldata to send with the calls.
     * @param descriptionHash The hash of the proposal's description.
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Cancels a proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The values (in wei) to send with the calls.
     * @param calldatas The calldata to send with the calls.
     * @param descriptionHash The hash of the proposal's description.
     * @return The ID of the canceled proposal.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Returns the address of the executor.
     * @return The address of the executor.
     */
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    /**
     * @notice Returns the proposal threshold.
     * @return The minimum number of tokens required to propose a new proposal.
     */
    function proposalThreshold() public view virtual override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
}
