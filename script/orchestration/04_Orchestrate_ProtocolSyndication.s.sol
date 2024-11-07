// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IDistributorFactory } from "contracts/interfaces/syndication/IDistributorFactory.sol";
import { IDistributorReferendum } from "contracts/interfaces/syndication/IDistributorReferendum.sol";

contract OrchestrateProtocolHydration is Script {
    function run() external {
        address mmc = vm.envAddress("MMC");
        uint256 admin = vm.envUint("PRIVATE_KEY");
        uint256 synFees = vm.envUint("SYNDICATION_FEES"); // 100 MMC flat fee
        address disitributorFactory = vm.envAddress("DISTRIBUTION_FACTORY");
        address distributorReferendum = vm.envAddress("DISTRIBUTION_REFERENDUM");

        vm.startBroadcast(admin);
        // approve initial distributor
        address distributor = IDistributorFactory(disitributorFactory).create("https://guardian.watchit.movie");
        IDistributorReferendum referendum = IDistributorReferendum(distributorReferendum);

        IERC20(mmc).approve(distributorReferendum, synFees);
        referendum.register(address(distributor), mmc);
        referendum.approve(address(distributor));
        vm.stopBroadcast();
    }
}
