// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BasePolicy } from "contracts/policies/BasePolicy.sol";
import { TreasuryHelper } from "contracts/libraries/TreasuryHelper.sol";
import { T } from "contracts/libraries/Types.sol";

/// @title RentalPolicy
/// @notice This contract implements the IPolicy interface to manage content rental terms.
/// It allows for registering content with rental durations and prices and handles the rental process.
contract RentalPolicy is BasePolicy {
    using TreasuryHelper for address;

    /// @dev Structure to hold rental details for content.
    struct Content {
        uint256 rentalDuration; // Duration in seconds for which content is rented.
        uint256 price; // Price to rent the content.
        address currency;
    }

    // Mapping to store content data by content ID.
    mapping(uint256 => Content) private contents;

    // Mapping to track rental expiration timestamps for each account and content.
    mapping(address => mapping(uint256 => uint256)) private rentals;

    /// @notice Constructor for the RentalPolicy contract.
    /// @param rmAddress Address of the Rights Manager (RM) contract.
    /// @param ownershipAddress Address of the Ownership contract.
    constructor(address rmAddress, address ownershipAddress) BasePolicy(rmAddress, ownershipAddress) {}

    /// @notice Returns the name of the policy.
    function name() external pure returns (string memory) {
        return "RentalPolicy";
    }

    /// @notice Returns the business/strategy model implemented by the policy.
    function description() external pure returns (bytes memory) {
        return
            abi.encodePacked(
                "This policy implements a strategy where users pay a fee to access content for a limited period.",
                "Key aspects of this policy include: \n\n",
                "1) Flexible rental duration: Each content can have a customized rental",
                "period defined by the content holder. \n",
                "2) Pay-per-use model: Users pay a one-time fee per rental, providing a",
                "cost-effective way to access content without a long-term commitment.\n ",
                "3) Automated rental management: Once the rental fee is paid, the content",
                "becomes accessible to the user for the specified duration,\n ",
                "after which access is automatically revoked.\n ",
                "4) Secure revenue distribution: The rental fee is transferred directly to the",
                "content holder through the TreasuryHelper, ensuring secure and \n",
                "timely payments. This policy provides a straightforward and transparent way for content",
                "owners to generate revenue from their digital assets \n",
                "while giving users temporary access to premium content."
            );
    }

    function setup(bytes calldata init) external initializer {
        (uint256 rentalDuration, uint256 contentId, uint256 price, address currency) = abi.decode(
            init,
            (uint256, uint256, uint256, address)
        );

        if (getHolder(contentId) != msg.sender) revert InvalidSetup("Rental: Invalid content id holder.");
        if (rentalDuration == 0) revert InvalidSetup("Rental: Invalid rental duration.");
        if (price == 0) revert InvalidSetup("Rental: Invalid rental price.");
        contents[contentId] = Content(rentalDuration, price, currency);
    }

    /// @notice Executes the agreement between the content holder and the account based on the policy's rules.
    /// @dev This function is expected to be called only by the Rights Manager (RM) contract.
    /// It handles any logic related to access and validation of the rental terms.
    /// @param agreement The agreement object containing the agreed terms between the content holder and the account.
    function exec(T.Agreement calldata agreement) external onlyRM initialized {
        uint256 contentId = abi.decode(agreement.payload, (uint256));
        Content memory content = contents[contentId];

        if (getHolder(contentId) != agreement.holder) revert InvalidExecution("Rental: Invalid content ID holder");
        if (agreement.total < content.price) revert InvalidExecution("Rental: Insufficient funds for rental");

        // We can take two approach here:
        // 1- distribute the funds
        // 2- register the total to rights holder
        _sumLedgerEntry(agreement.holder, agreement.available, agreement.currency);
        // Register the rental for the account with the rental duration.
        _registerRent(agreement.account, contentId, content.rentalDuration);
    }

    function assess(bytes calldata data) external view returns (T.Terms memory) {
        uint256 contentId = abi.decode(data, (uint256));
        Content memory content = contents[contentId];
        return T.Terms(content.currency, content.price, "");
    }

    /// @notice Verifies whether the on-chain access terms for an account and content ID are satisfied.
    /// @param account The address of the account to check.
    /// @param contentId The ID of the content to check against.
    function comply(address account, uint256 contentId) external view override returns (bool) {
        // Check if the current time is before the rental expiration.
        return block.timestamp <= rentals[account][contentId];
    }

    /// @dev Internal function to register the rental of content for a specific account.
    /// @param account The address of the account renting the content.
    /// @param contentId The ID of the content being rented.
    /// @param expire The expiration time (in seconds) for the rental.
    function _registerRent(address account, uint256 contentId, uint256 expire) private {
        rentals[account][contentId] = block.timestamp + expire;
    }
}
