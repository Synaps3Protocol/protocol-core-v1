// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ICustodian } from "@synaps3/core/interfaces/custody/ICustodian.sol";
import { IBalanceVerifiable } from "@synaps3/core/interfaces/base/IBalanceVerifiable.sol";
import { IBalanceWithdrawable } from "@synaps3/core/interfaces/base/IBalanceWithdrawable.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

// TODO impl ERC1271 to validate manager based signatures
// TODO add stateful management to custodians contract, the custodian can
// change his state to "maintenance mode" or "inactive" if its facing issues

/// @title CustodianImpl
/// @notice Handles the logic for managing content custodian in a decentralized environment.
/// @dev
/// - The `CustodianImpl` contract serves as an implementation for an `UpgradeableBeacon`.
/// - Calls to this contract are made through a `BeaconProxy`, allowing upgrades at the beacon level.
/// - This contract itself is NOT upgradeable directly; its updates are managed by the beacon.
/// - It inherits from upgradeable contracts **ONLY** to maintain compatibility with their storage layout (ERC-7201).
contract CustodianImpl is
    Initializable,
    ERC165Upgradeable,
    OwnableUpgradeable,
    ICustodian,
    IBalanceVerifiable,
    IBalanceWithdrawable
{
    using FinancialOps for address;

    /// @notice The custodian endpoint.
    string private _endpoint;

    /// @notice Event emitted when the distribution endpoint is updated.
    /// @param oldEndpoint The previous endpoint before the update.
    /// @param newEndpoint The new endpoint that is set.
    event EndpointUpdated(string oldEndpoint, string newEndpoint);

    /// @notice Error thrown when an invalid (empty) endpoint is provided.
    error InvalidEndpoint();

    /// @notice Initializes the Custodian contract with the specified endpoint and owner.
    /// @param endpoint The distribution endpoint URL.
    /// @param owner The address of the owner who will manage the custodian.
    /// @dev Ensures that the provided endpoint is valid and initializes ERC165 and Ownable contracts.
    function initialize(string calldata endpoint, address owner) external initializer {
        if (bytes(endpoint).length == 0) revert InvalidEndpoint();
        __ERC165_init();
        __Ownable_init(owner);
        _endpoint = endpoint;
    }

    /// @notice Checks if the contract supports a specific interface based on its ID.
    /// @param interfaceId The ID of the interface to check.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ICustodian).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Retrieves the manager (owner) of the custodian contract.
    function getManager() external view returns (address) {
        return owner();
    }

    /// TODO add method to return encoded multi-address. getAddress()
    /// @notice Returns the current distribution endpoint URL.
    function getEndpoint() external view returns (string memory) {
        return _endpoint;
    }

    /// @notice Updates the distribution endpoint URL.
    /// @param endpoint_ The new endpoint URL to be set.
    /// @dev Reverts if the provided endpoint is an empty string. Emits an {EndpointUpdated} event.
    function setEndpoint(string calldata endpoint_) external onlyOwner {
        if (bytes(endpoint_).length == 0) revert InvalidEndpoint();
        string memory oldEndpoint = _endpoint;
        _endpoint = endpoint_; // update the endpoint!
        emit EndpointUpdated(oldEndpoint, endpoint_);
    }

    /// @notice Withdraws tokens or native currency from the contract to the specified recipient.
    /// @param recipient The address that will receive the withdrawn tokens or native currency.
    /// @param amount The amount of tokens or native currency to withdraw.
    /// @param currency The address of the token to withdraw (use `address(0)` for native currency).
    /// @dev Transfers the specified amount of tokens or native currency to the recipient.
    /// Emits a {FundWithdrawn} event.
    function withdraw(address recipient, uint256 amount, address currency) external onlyOwner returns (uint256) {
        if (getBalance(currency) == 0) revert NoFundsToWithdraw();
        recipient.transfer(amount, currency); // transfer amount to recipient
        emit FundsWithdrawn(recipient, msg.sender, amount, currency);
        return amount;
    }

    // TODO allow deposits to stake balance

    /// @notice Retrieves the contract's balance for a given currency.
    /// @param currency The token address to check the balance of (use `address(0)` for native currency).
    /// @dev This function is restricted to the contract owner.
    function getBalance(address currency) public view returns (uint256) {
        return address(this).balanceOf(currency);
    }
}
