// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.26;

// import { BasePolicy } from "contracts/base/BasePolicy.sol";
// import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // For NFT gating
// import { T } from "contracts/libraries/Types.sol";

// /// @title GatedContentPolicy
// /// @notice Implements a content access policy where users must meet specific criteria to access the gated content.
// contract GatedContentPolicy is BasePolicy {
//     address public nftToken; // Address of the NFT token used for gating access.
//     mapping(address => mapping(uint256 => bool)) public accessList; // Tracks access by contentId.

//     /// @notice Constructor for the GatedContentPolicy contract.
//     /// @param rmAddress Address of the Rights Manager (RM) contract.
//     /// @param ownershipAddress Address of the Ownership contract.
//     /// @param nftTokenAddress Address of the NFT token contract used for gating.
//     constructor(
//         address rmAddress,
//         address ownershipAddress,
//         address nftTokenAddress
//     ) BasePolicy(rmAddress, ownershipAddress) {
//         nftToken = nftTokenAddress;
//     }

//     /// @notice Returns the name of the policy.
//     /// @return The name of the policy, "RentalPolicy".
//     function name() external pure override returns (string memory) {
//         return "GatedPolicy";
//     }

//     /// @notice Register a user on the whitelist for specific content.
//     /// @param user The address of the user to be whitelisted.
//     /// @param contentId The ID of the content.
//     function addToWhitelist(address user, uint256 contentId) external onlyOwner(contentId) {
//         accessList[user][contentId] = true;
//     }

//     /// @notice Check whether a user meets the access criteria for a specific content.
//     /// @param account The address of the account to check.
//     /// @param contentId The ID of the content to check.
//     /// @return bool Returns true if the user has access to the content.
//     function comply(address account, uint256 contentId) public view override returns (bool) {
//         bool ownsNFT = IERC721(nftToken).balanceOf(account) > 0;
//         bool isWhitelisted = accessList[account][contentId];

//         return ownsNFT || isWhitelisted;
//     }

//     /// @notice Execute the logic of access validation.
//     /// @param agreement The agreement object containing the terms agreed upon between the content holder and the user.
//     /// @param data Additional data needed for processing the agreement.
//     /// @return bool A boolean indicating whether the execution was successful.
//     /// @return string A message providing context for the execution result.
//     function exec(T.Agreement calldata agreement, bytes calldata data) external onlyRM returns (bool, string memory) {
//         // TODO custom list of conditions..
//     }

//     /// @notice Retrieves the access terms for a specific account and content ID.
//     /// @param account The address of the account for which access terms are being retrieved.
//     /// @param contentId The ID of the content associated with the access terms.
//     /// @return The access terms as a `bytes` array, which can contain the rental expiration timestamp.
//     function terms(address account, uint256 contentId) external view override returns (bytes memory) {
//         return "";
//     }

//     /// @notice Returns a detailed description of the gated content policy.
//     function description() external pure override returns (bytes memory) {
//         return
//             abi.encodePacked(
//                 "The GatedContentPolicy restricts access to content based on user criteria such as owning a specific NFT, ",
//                 "being whitelisted by the content holder, or paying an access fee. Users must fulfill at least one of these criteria ",
//                 "to access the gated content."
//             );
//     }
// }
