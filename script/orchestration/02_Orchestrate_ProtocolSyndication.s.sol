// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILedgerVault } from "contracts/core/interfaces/financial/ILedgerVault.sol";
import { IDistributor } from "contracts/core/interfaces/syndication/IDistributor.sol";
import { IDistributorFactory } from "contracts/core/interfaces/syndication/IDistributorFactory.sol";
import { IDistributorReferendum } from "contracts/core/interfaces/syndication/IDistributorReferendum.sol";

contract OrchestrateProtocolSyndication is DeployBase {
    function run() external {
        uint256 admin = getAdminPK();
        address mmc = vm.envAddress("MMC");
        uint256 synFees = vm.envUint("SYNDICATION_FEES"); // 100 MMC flat fee
        address vault = computeCreate3Address("SALT_LEDGER_VAULT");
        address distributorFactory = vm.envAddress("DISTRIBUTION_FACTORY");
        address distributorReferendum = vm.envAddress("DISTRIBUTION_REFERENDUM");

        vm.startBroadcast(admin);
        // approve initial distributor
        address distributor = IDistributorFactory(distributorFactory).create("https://g.watchit.movie");
        IDistributorReferendum referendum = IDistributorReferendum(distributorReferendum);

        bytes32 got = keccak256(abi.encodePacked(IDistributor(distributor).getEndpoint()));
        bytes32 expected = keccak256(abi.encodePacked("https://g.watchit.movie"));

        require(IDistributor(distributor).getManager() == vm.addr(admin));
        require(got == expected);

        // deposit funds to register distributor
        IERC20(mmc).approve(vault, synFees);
        ILedgerVault(vault).deposit(vm.addr(admin), synFees, mmc);

        referendum.register(address(distributor), mmc);
        referendum.approve(address(distributor));
        vm.stopBroadcast();

        _logAddress("DEFAULT_DISTRIBUTOR_ADDRESS", distributor);
    }
}
