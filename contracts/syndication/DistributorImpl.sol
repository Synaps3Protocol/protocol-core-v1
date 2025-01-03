// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IDistributor } from "@synaps3/core/interfaces/syndication/IDistributor.sol";
import { FinancialOps } from "@synaps3/core/libraries/FinancialOps.sol";

/// @title Asset Distributor Implementation
/// @notice This contract handles all the necessary logic for managing content distributors.
contract DistributorImpl is Initializable, ERC165Upgradeable, OwnableUpgradeable, IDistributor {
    using FinancialOps for address;

    /// @notice The distribution endpoint URL.
    string private endpoint;

    /// @notice Event emitted when the distribution endpoint is updated.
    /// @param oldEndpoint The previous endpoint before the update.
    /// @param newEndpoint The new endpoint that is set.
    event EndpointUpdated(string oldEndpoint, string newEndpoint);

    /// @notice Error thrown when an invalid (empty) endpoint is provided.
    error InvalidEndpoint();

    /// @notice Initializes the Distributor contract with the specified endpoint and owner.
    /// @param _endpoint The distribution endpoint URL.
    /// @param _owner The address of the owner who will manage the distributor.
    /// @dev Ensures that the provided endpoint is valid and initializes ERC165 and Ownable contracts.
    function initialize(string calldata _endpoint, address _owner) external initializer {
        if (bytes(_endpoint).length == 0) revert InvalidEndpoint();
        __ERC165_init();
        __Ownable_init(_owner);
        endpoint = _endpoint;
    }

    /// @notice Checks if the contract supports a specific interface based on its ID.
    /// @param interfaceId The ID of the interface to check.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IDistributor).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Retrieves the manager (owner) of the distributor contract.
    function getManager() external view returns (address) {
        return owner();
    }

    /// @notice Returns the current distribution endpoint URL.
    function getEndpoint() external view returns (string memory) {
        return endpoint;
    }

    /// @notice Updates the distribution endpoint URL.
    /// @param _endpoint The new endpoint URL to be set.
    /// @dev Reverts if the provided endpoint is an empty string. Emits an {EndpointUpdated} event.
    function setEndpoint(string calldata _endpoint) external onlyOwner {
        if (bytes(_endpoint).length == 0) revert InvalidEndpoint();
        string memory oldEndpoint = endpoint;
        endpoint = _endpoint;
        emit EndpointUpdated(oldEndpoint, _endpoint);
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

    /// @notice Retrieves the contract's balance for a given currency.
    /// @param currency The token address to check the balance of (use `address(0)` for native currency).
    /// @dev This function is restricted to the contract owner.
    function getBalance(address currency) public view onlyOwner returns (uint256) {
        return address(this).balanceOf(currency);
    }
}
