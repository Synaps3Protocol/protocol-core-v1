// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BasePolicy } from "contracts/policies/BasePolicy.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title SubscriptionPolicy
/// @notice Implements a subscription-based content access policy.
contract SubscriptionPolicy is BasePolicy {
    /// @dev Structure to define a subscription package.
    struct Package {
        uint256 pricePerDay; // Price of the subscription package.
        address currency;
    }

    // Mapping from content holder (address) to their subscription package details.
    mapping(address => Package) private _packages;

    constructor(
        address rmAddress,
        address ownershipAddress,
        address providerAddress
    ) BasePolicy(rmAddress, ownershipAddress, providerAddress) {}

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
                "3) Immediate access to content catalog during the subscription period."
            );
    }

    function initialize(bytes calldata init) external initializer {
        (uint256 price, address currency) = abi.decode(init, (uint256, address));
        if (price == 0) revert InvalidInitialization("InvalidInitialization Invalid subscription price.");
        // expected content rigInvalidInitializationending subscription params..
        _packages[msg.sender] = Package(price, currency);
    }

    // this function should be called only by RM and its used to establish
    // any logic or validation needed to set the authorization parameters
    // de modo qu en el futuro se pueda usar otro tipo de estructuras como group
    function enforce(address holder, T.Agreement calldata agreement) external onlyRM initialized returns (uint256) {
        Package memory pkg = _packages[holder];
        // we need to be sure the user paid for the total of the package..
        uint256 paymentPerAccount = agreement.amount / agreement.parties.length;
        uint256 subscriptionDuration = paymentPerAccount / pkg.pricePerDay; // expected payment per day per account
        uint256 total = (subscriptionDuration * pkg.pricePerDay) * agreement.parties.length; // total to pay for the total of subscriptions
        if (agreement.amount < total) revert InvalidEnforcement("Insufficient funds for subscription");

        // subscribe to content owner's catalog (content package)
        uint256 subExpire = block.timestamp + (subscriptionDuration * 1 days);
        // the agreement is stored in an attestation signed registry
        // the recipients is the list of benefitians of the agreement
        return _commit(holder, agreement, subExpire);
    }

    function resolveTerms(bytes calldata criteria) external view returns (T.Terms memory) {
        address holder = abi.decode(criteria, (address));
        Package memory pkg = _packages[holder];
        return T.Terms(pkg.currency, pkg.pricePerDay, "");
    }
}
