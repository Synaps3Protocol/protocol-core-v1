// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.26;

// import { DeployBase } from "script/00_Deploy_Base.s.sol";
// import { DistributorReferendum } from "contracts/syndication/DistributorReferendum.sol";

// contract DeployContentVault is DeployBase {

//     function setTreasuryAddress(address treasury_) external {
//         treasury = treasury_;
//     }

//     function setTollgateAddress(address tollgate_) external {
//         tollgate = tollgate_;
//     }

//     function run() external BroadcastedByAdmin returns (address) {
//         return
//             deployUUPS(
//                 "DistributorReferendum.sol",
//                 abi.encodeCall(DistributorReferendum.initialize, ()),
//                 abi.encode(treasury, tollgate)
//             );
//     }
// }
