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
        address rightPolicyManagerAddress,
        address ownershipAddress,
        address providerAddress
    ) BasePolicy(rightPolicyManagerAddress, ownershipAddress, providerAddress) {}

    /// @notice Returns the name of the policy.
    function name() external pure returns (string memory) {
        return "SubscriptionPolicy";
    }

    /// @notice Returns the business/strategy model implemented by the policy.
    function description() external pure returns (string memory) {
        return
            "This policy follows a subscription model with daily pricing, allowing users to access "
            "a content holder's catalog by paying a daily fee for a chosen duration.\n\n"
            "Key features:\n"
            "1) Flexible subscription periods set by the asset holder.\n"
            "2) Instant access to all content during the subscription period.";
    }

    function initialize(address holder, bytes calldata init) external onlyPolicyAuthorizer initializer {
        (uint256 price, address currency) = abi.decode(init, (uint256, address));
        if (price == 0) revert InvalidInitialization("Invalid subscription price.");
        // expected content rigInvalidInitializationending subscription params..
        _packages[holder] = Package(price, currency);
    }

    // this function should be called only by RM and its used to establish
    // any logic or validation needed to set the authorization parameters
    // de modo qu en el futuro se pueda usar otro tipo de estructuras como group
    function enforce(
        address holder,
        T.Agreement calldata agreement
    ) external onlyPolicyManager initialized returns (uint256) {
        Package memory pkg = _packages[holder];
        // we need to be sure the user paid for the total of the package..
        uint256 paymentPerAccount = agreement.amount / agreement.parties.length;
        // expected payment per day per account
        uint256 subscriptionDuration = paymentPerAccount / pkg.pricePerDay;
        // total to pay for the total of subscriptions
        // TODO log decay days > more days, less price
        uint256 total = (subscriptionDuration * pkg.pricePerDay) * agreement.parties.length;
        if (agreement.amount < total) revert InvalidEnforcement("Insufficient funds for subscription");

        // subscribe to content owner's catalog (content package)
        uint256 subExpire = block.timestamp + (subscriptionDuration * 1 days);
        // the agreement is stored in an attestation signed registry
        // the recipients is the list of benefitians of the agreement
        return _commit(holder, agreement, subExpire);
    }

    /// @notice Retrieves the terms associated with a specific rights holder.
    function resolveTerms(address holder) external view override returns (T.Terms memory) {
        Package memory pkg = _packages[holder]; // the term set by the asset holder
        return T.Terms(pkg.currency, pkg.pricePerDay, T.RateBasis.DAILY, "ipfs://");
    }
}
