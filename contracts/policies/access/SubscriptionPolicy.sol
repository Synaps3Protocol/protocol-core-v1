// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BasePolicy } from "@synaps3/policies/BasePolicy.sol";
import { T } from "@synaps3/core/primitives/Types.sol";

/// @title SubscriptionPolicy
/// @notice Implements a subscription-based content access policy.
contract SubscriptionPolicy is BasePolicy {
    /// @dev Structure to define a subscription package.
    struct Package {
        uint256 pricePerDay;
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
    function enforce(
        address holder,
        T.Agreement calldata agreement
    ) external onlyPolicyManager initialized returns (uint256[] memory) {
        Package memory pkg = _packages[holder];
        if (pkg.pricePerDay == 0) {
            // if the holder has not set the package details, can not process the agreement
            revert InvalidEnforcement("Invalid not initialized holder conditions");
        }

        uint256 paidAmount = agreement.amount;
        uint256 partiesLen = agreement.parties.length;
        uint256 pricePerDay = pkg.pricePerDay;
        // verify if the paid amount is valid based on total expected + parties
        uint256 duration = _verifyDaysFromAmount(paidAmount, pricePerDay, partiesLen);
        // subscribe to content owner's catalog (content package)
        uint256 subExpire = block.timestamp + (duration * 1 days);
        return _commit(holder, agreement, subExpire);
    }

    /// @notice Verifies if a specific account has access to a particular asset based on `assetId`.
    function isAccessAllowed(address account, uint256 assetId) external view override returns (bool) {
        // Default behavior: only check attestation compliance.
        address holder = getHolder(assetId);
        return isCompliant(account, holder);
    }

    /// @notice Verifies if a specific account has general access holder's rights .
    function isAccessAllowed(address account, address holder) external view override returns (bool) {
        // Default behavior: only check attestation compliance.
        return isCompliant(account, holder);
    }

    /// @notice Retrieves the terms associated with a specific rights holder.
    function resolveTerms(address holder) external view override returns (T.Terms memory) {
        Package memory pkg = _packages[holder]; // the term set by the asset holder
        return T.Terms(pkg.pricePerDay, pkg.currency, T.RateBasis.DAILY, "ipfs://");
    }

    function _verifyDaysFromAmount(
        uint256 amount,
        uint256 pricePerDay,
        uint256 partiesLen
    ) private pure returns (uint256) {
        // we need to be sure the user paid for the total of the package..
        uint256 paymentPerAccount = amount / partiesLen;
        // expected payment per day per account
        uint256 subscriptionDuration = paymentPerAccount / pricePerDay;
        // total to pay for the total of subscriptions
        uint256 total = (subscriptionDuration * pricePerDay) * partiesLen;
        if (amount < total) revert InvalidEnforcement("Insufficient funds for subscription");
        return subscriptionDuration;
    }
}
