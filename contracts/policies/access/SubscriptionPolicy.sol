// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BasePolicy } from "contracts/policies/BasePolicy.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title SubscriptionPolicy
/// @notice Implements a subscription-based content access policy.
contract SubscriptionPolicy is BasePolicy {
    /// @dev Structure to define a subscription package.
    struct Package {
        uint256 subscriptionDuration; // Duration in seconds for which the subscription is valid.
        uint256 price; // Price of the subscription package.
        address currency;
    }

    // Mapping from content holder (address) to their subscription package details.
    mapping(address => Package) private packages;

    constructor(
        address rmAddress,
        address ownershipAddress,
        address spiAddress
    ) BasePolicy(rmAddress, ownershipAddress, spiAddress) {}

    /// @notice Returns the name of the policy.
    function name() external pure returns (string memory) {
        return "SubscriptionPolicy";
    }

    /// @notice Returns the business/strategy model implemented by the policy.
    function description() external pure returns (bytes memory) {
        return
            abi.encodePacked(
                "This policy implements a subscription-based model where users pay a fixed fee "
                "to access a content holder's catalog for a specified duration.\n\n"
                "1) Flexible subscription duration, defined by the content holder.\n"
                "2) Recurring revenue streams for content holders.\n"
                "3) Immediate access to content catalog during the subscription period.\n"
                "4) Automated payment processing."
            );
    }

    function initialize(bytes calldata init) external initializer {
        (uint256 subscriptionDuration, uint256 price, address currency) = abi.decode(init, (uint256, uint256, address));
        if (subscriptionDuration == 0) revert InvalidSetup("Subscription: Invalid subscription duration.");
        if (price == 0) revert InvalidSetup("Subscription: Invalid subscription price.");
        // expected content rights holder sending subscription params..
        packages[msg.sender] = Package(subscriptionDuration, price, currency);
    }

    // this function should be called only by RM and its used to establish
    // any logic or validation needed to set the authorization parameters
    // de modo qu en el futuro se pueda usar otro tipo de estructuras como group
    function enforce(T.Agreement calldata agreement) external onlyRM initialized returns (uint256) {
        Package memory pkg = packages[agreement.holder];
        // we need to be sure the user paid for the total of the price..
        uint256 total = agreement.parties.length * pkg.price; // total to pay for the total of subscriptions
        if (pkg.subscriptionDuration == 0) revert InvalidExecution("Invalid not existing subscription");
        if (agreement.total < total) revert InvalidExecution("Insufficient funds for subscription");

        // subscribe to content owner's catalog (content package)
        uint256 subExpire = block.timestamp + pkg.subscriptionDuration;
        _sumLedgerEntry(agreement.holder, agreement.available, agreement.currency);
        // the agreement is stored in an attestation signed registry
        // the recipients is the list of benefitians of the agreement
        return commit(agreement, subExpire);
    }

    function resolveTerms(bytes calldata criteria) external view returns (T.Terms memory) {
        address holder = abi.decode(criteria, (address));
        Package memory pkg = packages[holder];
        return T.Terms(pkg.currency, pkg.price, "");
    }

    function isAccessValid(address, uint256) internal pure override returns (bool) {
        // since the subscription is enforced directly by attestment expiration
        // by default, we don't need to add any additional check here
        return true;
    }

}
