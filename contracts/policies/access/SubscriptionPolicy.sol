// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BasePolicy } from "contracts/policies/BasePolicy.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title SubscriptionPolicy
/// @notice Implements a subscription-based content access policy.
contract SubscriptionPolicy is BasePolicy {
    using SafeERC20 for IERC20;

    /// @dev Structure to define a subscription package.
    struct Package {
        uint256 subscriptionDuration; // Duration in seconds for which the subscription is valid.
        uint256 price; // Price of the subscription package.
        address currency;
    }

    // Mapping from content holder (address) to their subscription package details.
    mapping(address => Package) private packages;

    // Mapping to track subscription expiration for each user (account) and content holder.
    mapping(address => mapping(address => uint256)) private subscriptions;

    /// @notice Constructor for the SubscriptionPolicy contract.
    /// @param rmAddress Address of the Rights Manager (RM) contract.
    /// @param ownershipAddress Address of the Ownership contract.
    constructor(address rmAddress, address ownershipAddress) BasePolicy(rmAddress, ownershipAddress) {}

    /// @notice Returns the name of the policy.
    /// @return The name of the policy, "SubscriptionPolicy".
    function name() external pure returns (string memory) {
        return "SubscriptionPolicy";
    }

    /// @notice Returns the business/strategy model implemented by the policy.
    /// @return A detailed description of the subscription policy as bytes.
    function description() external pure returns (bytes memory) {
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

    function setup(T.Setup calldata setup) external onlyRM initializer {
        (uint256 subscriptionDuration, uint256 price, address currency) = abi.decode(
            setup.payload,
            (uint256, uint256, address)
        );

        // require(isValidCurrency(currency), "Subscription: Invalid currency.");
        require(subscriptionDuration > 0, "Subscription: Invalid subscription duration.");
        require(price > 0, "Subscription: Invalid subscription price.");
        // expected content rights holder sending subscription params..
        packages[setup.holder] = Package(subscriptionDuration, price, currency);
    }

    // this function should be called only by RM and its used to establish
    // any logic or validation needed to set the authorization parameters
    function exec(T.Agreement calldata agreement) external onlyRM initialized {
        Package memory pkg = packages[agreement.holder];
        // we need to be sure the user paid for the total of the price..
        require(agreement.total >= pkg.price, "Insufficient funds for subscription");
        uint256 subTime = block.timestamp + pkg.subscriptionDuration;
        // subscribe to content owner's catalog (content package)
        subscriptions[agreement.account][agreement.holder] = subTime;
        _sumLedgerEntry(agreement.holder, agreement.available, agreement.currency);
    }

    function assess(bytes calldata data) external view returns (T.Terms memory) {
        address holder = abi.decode(data, (address));
        Package memory pkg = packages[holder];
        return T.Terms(pkg.currency, pkg.price, "");
    }

    function comply(address account, uint256 contentId) external view override returns (bool) {
        address holder = getHolder(contentId);
        return block.timestamp <= subscriptions[account][holder];
    }
}
