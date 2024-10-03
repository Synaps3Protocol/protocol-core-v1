// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BasePolicy } from "contracts/base/BasePolicy.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title SubscriptionPolicy
/// @notice Implements a subscription-based content access policy, allowing users to subscribe to content catalogs for a set duration.
contract SubscriptionPolicy is BasePolicy {
    using SafeERC20 for IERC20;

    /// @dev Structure to define a subscription package.
    struct Package {
        uint256 subscriptionDuration; // Duration in seconds for which the subscription is valid.
        uint256 price; // Price of the subscription package.
    }

    // Mapping from content holder (address) to their subscription package details.
    mapping(address => Package) public packages;

    // Mapping to track subscription expiration for each user (account) and content holder.
    mapping(address => mapping(address => uint256)) private subscriptions;

    /// @notice Constructor for the SubscriptionPolicy contract.
    /// @param rmAddress Address of the Rights Manager (RM) contract.
    /// @param ownershipAddress Address of the Ownership contract.
    constructor(address rmAddress, address ownershipAddress) BasePolicy(rmAddress, ownershipAddress) {}

    /// @notice Returns the name of the policy.
    /// @return The name of the policy, "SubscriptionPolicy".
    function name() external pure override returns (string memory) {
        return "SubscriptionPolicy";
    }

    /// @notice Returns the business/strategy model implemented by the policy.
    /// @return A detailed description of the subscription policy as bytes.
    function description() external pure override returns (bytes memory) {
        return
            abi.encodePacked(
                "This policy implements a subscription-based model where users pay a fixed fee ",
                "to access a content holder's catalog for a specified duration.\n\n",
                "1) Flexible subscription duration, defined by the content holder.\n",
                "2) Recurring revenue streams for content holders.\n",
                "3) Immediate access to content catalog during the subscription period.\n",
                "4) Automated payment processing."
            );
    }

    /// @notice Registers a subscription package for the content holder.
    /// @param subscriptionDuration The duration of the subscription in seconds.
    /// @param price The price of the subscription package.
    function registerPackage(uint256 subscriptionDuration, uint256 price) external {
        require(subscriptionDuration > 0);
        require(price > 0);
        // only native token is approached in this example
        // expected content rights holder sending subscription params..
        packages[msg.sender] = Package(subscriptionDuration, price);
    }

    // this function should be called only by RM and its used to establish
    // any logic or validation needed to set the authorization parameters
    function exec(T.Agreement calldata agreement, bytes calldata) external onlyRM returns (bool, string memory) {
        Package memory pkg = packages[agreement.holder];
        // we need to be sure the user paid for the total of the price..
        if (agreement.total < pkg.price) return (false, "Insufficient funds for subscription");
        uint256 subTime = block.timestamp + pkg.subscriptionDuration;
        // subscribe to content owner's catalog (content package)
        subscriptions[agreement.account][agreement.holder] = subTime;
        // We can take two approach here:
        // 1- distribute the funds
        // 2- register the total to rights holder
        _sumLedgerEntry(agreement.holder, agreement.available, agreement.currency);

        return (true, "ok");
    }

    function terms(address, uint256 contentId) external view override returns (bytes memory) {
        address holder = getHolder(contentId);
        return abi.encode(packages[holder]);
    }

    function comply(address account, uint256 contentId) external view override returns (bool) {
        address holder = getHolder(contentId);
        return block.timestamp <= subscriptions[account][holder];
    }
}