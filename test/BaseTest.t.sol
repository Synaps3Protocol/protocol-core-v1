pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { DeployTreasury } from "script/01_Deploy_Economics_Treasury.s.sol";
import { DeployTollgate } from "script/02_Deploy_Economics_Tollgate.s.sol";
import { DeployToken } from "script/03_Deploy_Economics_Token.s.sol";
import { DeployDistributor } from "script/04_Deploy_Syndication_Distributor.s.sol";
import { DeployContentReferendum } from "script/05_Deploy_Assets_ContentReferendum.s.sol";
import { DeployDistributorReferendum } from "script/08_Deploy_Syndication_DistributorReferendum.s.sol";

import { IGovernable } from "contracts/interfaces/IGovernable.sol";

contract BaseTest is Test {
    address admin = vm.envAddress("PUBLIC_KEY");
    address user = vm.addr(2);
    address governor = vm.addr(1);

    // Helper function to governor to contract.
    function setGovernorTo(address governable) public {
        // setup governor account for testing purposes
        // some methods are restricted to be called by governance only
        vm.prank(admin); // only admin can set initially a governor
        IGovernable(governable).setGovernance(governor);
    }


    // 01_DeployTreasury
    function deployTreasury() public returns (address) {
        // set default admin as deployer..
        DeployTreasury treasuryDeployer = new DeployTreasury();
        return treasuryDeployer.run();
    }

    // 02_DeployTollgate
    function deployTollgate() public returns (address) {
        // set default admin as deployer..
        DeployTollgate tollgateDeployer = new DeployTollgate();
        return tollgateDeployer.run();
    }

    // 03_DeployToken
    function deployToken() public returns (address) {
        // set default admin as deployer..
        DeployToken mmcDeployer = new DeployToken();
        return mmcDeployer.run();
    }

    // 04_DeployDistributor
    function deployDistributor(string memory endpoint) public returns (address) {
        DeployDistributor distDeployer = new DeployDistributor();
        distDeployer.setEndpoint(endpoint);
        return distDeployer.run();
    }

    // 05_DeployContentReferendum
    function deployContentReferendum() public returns (address) {
        DeployContentReferendum contentReferendumDeployer = new DeployContentReferendum();
        return contentReferendumDeployer.run();
    }

    // 08_DeployDistributorReferendum
    function deployDistributorReferendum(address treasury, address tollgate) public returns (address) {
        // set default admin as deployer..
        DeployDistributorReferendum distReferendumDeployer = new DeployDistributorReferendum();
        distReferendumDeployer.setTreasuryAddress(treasury);
        distReferendumDeployer.setTollgateAddress(tollgate);
        return distReferendumDeployer.run();
    }
}
