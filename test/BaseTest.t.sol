pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { DeployAccessManager } from "script/deployment/01_Deploy_Access_AccessManager.s.sol";
import { DeployTollgate } from "script/deployment/02_Deploy_Economics_Tollgate.s.sol";
import { DeployToken } from "script/deployment/03_Deploy_Economics_Token.s.sol";
import { DeployTreasury } from "script/deployment/04_Deploy_Economics_Treasury.s.sol";
import { DeployContentReferendum } from "script/deployment/05_Deploy_Content_ContentReferendum.s.sol";
import { DeployDistributorFactory } from "script/deployment/08_Deploy_Syndication_DistributorFactory.s.sol";
import { DeployDistributorReferendum } from "script/deployment/09_Deploy_Syndication_DistributorReferendum.s.sol";

import { IDistributorFactory } from "contracts/interfaces/syndication/IDistributorFactory.sol";
import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";

contract BaseTest is Test {
    address admin = vm.envAddress("PUBLIC_KEY");
    address user = vm.addr(2);
    address governor = vm.addr(1);
    address accessManager;

    function setAccessManager(address accessManager_) internal {
        accessManager = accessManager_;
        // setup governor account for testing purposes
        // some methods are restricted to be called by governance only
        vm.prank(admin);
        IAccessManager(accessManager).setGovernor(governor);
    }

    function deployAndSetAccessManager() public returns (address) {
        address accessManager_ = deployAccessManager();
        setAccessManager(accessManager_);
        return accessManager_;
    }

    // 01_DeployAccessManager
    function deployAccessManager() public returns (address) {
        // set default admin as deployer..
        DeployAccessManager accessManagerDeployer = new DeployAccessManager();
        return accessManagerDeployer.run();
    }

    // 02_DeployTollgate
    function deployTollgate() public returns (address) {
        // set default admin as deployer..
        DeployTollgate tollgateDeployer = new DeployTollgate();
        tollgateDeployer.setAccessManager(accessManager);
        return tollgateDeployer.run();
    }

    // 03_DeployToken
    function deployToken() public returns (address) {
        // set default admin as deployer..
        DeployToken mmcDeployer = new DeployToken();
        return mmcDeployer.run();
    }

    // 04_DeployTreasury
    function deployTreasury() public returns (address) {
        // set default admin as deployer..
        DeployTreasury treasuryDeployer = new DeployTreasury();
        treasuryDeployer.setAccessManager(accessManager);
        return treasuryDeployer.run();
    }

    // 05_DeployContentReferendum
    function deployContentReferendum() public returns (address) {
        DeployContentReferendum contentReferendumDeployer = new DeployContentReferendum();
        contentReferendumDeployer.setAccessManager(accessManager);
        return contentReferendumDeployer.run();
    }

    // 08_DeployDistributor
    function deployDistributor(string memory endpoint) public returns (address) {
        DeployDistributorFactory distDeployer = new DeployDistributorFactory();
        address distFactory = distDeployer.run();

        vm.prank(admin);
        IDistributorFactory factory = IDistributorFactory(distFactory);
        return factory.create(endpoint);
    }

    // 09_DeployDistributorReferendum
    function deployDistributorReferendum(address treasury, address tollgate) public returns (address) {
        // set default admin as deployer..
        DeployDistributorReferendum distReferendumDeployer = new DeployDistributorReferendum();
        distReferendumDeployer.setTreasuryAddress(treasury);
        distReferendumDeployer.setTollgateAddress(tollgate);
        distReferendumDeployer.setAccessManager(accessManager);
        return distReferendumDeployer.run();
    }
}
