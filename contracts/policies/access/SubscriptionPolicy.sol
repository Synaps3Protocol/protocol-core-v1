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
        // expected content subscription params..
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

        uint256 paidAmount = agreement.total;
        uint256 partiesLen = agreement.parties.length;
        uint256 pricePerDay = pkg.pricePerDay;
        // verify if the paid amount is valid based on total expected + parties
        uint256 duration = _verifyDaysFromAmount(paidAmount, pricePerDay, partiesLen);
        // subscribe to content owner's catalog (content package)
        uint256 subExpire = block.timestamp + (duration * 1 days);
        return _commit(holder, agreement, subExpire);
    }

    // TODOpotential improvement to scaling custom actions in protocol using hooks
    // function isAccessAllowed(bytes calldata criteria) external view return (bool) {
    //  IHook hook = HOOKS.get(address(this), IAccessHook) <- internal handling of any logic needed to get the valid hook
    //  if (!hook) return false // need conf hook
    //  return hook.exec(criteria)
    //}

    /// @notice Verifies if a specific account has general access holder's rights .
    function isAccessAllowed(address account, bytes calldata criteria) external view returns (bool) {
        // Default behavior: only check attestation compliance.
        // we expect always two inputs eg: (address, address) or (address, uint256)
        if (criteria.length != 32) revert InvalidNotSupportedOperation();
        // Detecting the "address shape" for the second argument to handle polymorphic validation.
        // If the second argument has the structure of an address (20 bytes with 12 leading zero bytes),
        // it is treated as a `holder`. Otherwise, it is treated as an `assetId`.
        // The likelihood of a mismatch in this validation is low, as `assetId` is expected to be a long integer.
        // https://github.com/ethereum/solidity-examples/blob/master/docs/bytes/Bytes.md
        // TODO: potential improvement: 
        // https://github.com/ethereum/solidity/issues/10381
        // https://forum.soliditylang.org/t/call-for-feedback-the-future-of-try-catch-in-solidity/1497
        bool last20Valid = bytes20(criteria[12:32]) != bytes20(0);
        bool first12Valid = bytes12(criteria[0:12]) == bytes12(0);
        if (last20Valid && first12Valid) {
            // match the holder
            address holder = abi.decode(criteria, (address));
            return isCompliant(account, holder);
        }

        // validate access on asset id criteria
        uint256 assetId = abi.decode(criteria, (uint256));
        return isCompliant(account, getHolder(assetId));
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
