// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { DeployCreate3Factory } from "script/deployment/01_Deploy_Base_Create3.s.sol";
import { DeployAccessManager } from "script/deployment/02_Deploy_Access_AccessManager.s.sol";
import { DeployTollgate } from "script/deployment/04_Deploy_Economics_Tollgate.s.sol";
import { DeployToken } from "script/deployment/03_Deploy_Economics_Token.s.sol";
import { DeployTreasury } from "script/deployment/05_Deploy_Economics_Treasury.s.sol";
import { DeployContentReferendum } from "script/deployment/06_Deploy_Content_ContentReferendum.s.sol";
import { DeployDistributorFactory } from "script/deployment/09_Deploy_Syndication_DistributorFactory.s.sol";
import { DeployDistributorReferendum } from "script/deployment/10_Deploy_Syndication_DistributorReferendum.s.sol";

import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { C } from "contracts/libraries/Constants.sol";

import {console} from "forge-std/console.sol";

abstract contract BaseTest is Test {
    address admin = vm.addr(vm.envUint("PRIVATE_KEY"));
    address user;
    address governor;
    address accessManager;

    modifier initialize() {
        // setup the admin to operate in tests..
        user = vm.addr(2);
        governor = vm.addr(1);
        admin = vm.addr(vm.envUint("PRIVATE_KEY"));
        deployCreate3Factory();
        deployAccessManager();
        _;
    }

    // 01_DeployAccessManager
    function deployCreate3Factory() public {
        // set default admin as deployer..
        DeployCreate3Factory create3 = new DeployCreate3Factory();
        address factory = create3.run();
        // we need access to create3 factory globally
        string memory factoryAddress = Strings.toHexString(factory);
        vm.setEnv("CREATE3_FACTORY", factoryAddress);
    }

    // 01_DeployAccessManager
    function deployAccessManager() public {
        // set default admin as deployer..
        DeployAccessManager accessManagerDeployer = new DeployAccessManager();
        accessManager = accessManagerDeployer.run();
    }

    // 02_DeployTollgate
    function deployTollgate() public returns (address) {
        // set default admin as deployer..
        DeployTollgate tollgateDeployer = new DeployTollgate();
        bytes4[] memory tollgateAllowed = tollgateDeployer.getGovPermissions();
        address tollgate = tollgateDeployer.run();
        _setTargetGovRole(tollgate, tollgateAllowed);
        return tollgate;
    }

    // 03_DeployToken
    function deployToken() public returns (address) {
        // set default admin as deployer..
        DeployToken mmcDeployer = new DeployToken();
        address token = mmcDeployer.run();
        return token;
    }

    // 04_DeployTreasury
    function deployTreasury() public returns (address) {
        // set default admin as deployer..
        DeployTreasury treasuryDeployer = new DeployTreasury();
        bytes4[] memory treasuryAllowed = treasuryDeployer.getGovPermissions();
        address treasury = treasuryDeployer.run();
        _setTargetGovRole(treasury, treasuryAllowed);
        return treasury;
    }

    // 05_DeployContentReferendum
    function deployContentReferendum() public returns (address) {
        // set default admin as deployer..
        DeployContentReferendum contentReferendumDeployer = new DeployContentReferendum();
        bytes4[] memory referendumAllowed = contentReferendumDeployer.getGovPermissions();
        address contentReferendum = contentReferendumDeployer.run();
        _setTargetGovRole(contentReferendum, referendumAllowed);
        return contentReferendum;
    }

    // 08_DeployDistributor
    function deployDistributorFactory() public returns (address) {
        DeployDistributorFactory distDeployer = new DeployDistributorFactory();
        return distDeployer.run();
    }


    // 09_DeployDistributorReferendum
    function deployDistributorReferendum() public returns (address) {
        // set default admin as deployer..
        DeployDistributorReferendum distReferendumDeployer = new DeployDistributorReferendum();
        bytes4[] memory distributorReferendumAllowed = distReferendumDeployer.getGovPermissions();
        address distributorReferendum = distReferendumDeployer.run();
        _setTargetGovRole(distributorReferendum, distributorReferendumAllowed);
        return distributorReferendum;
    }

    function _setTargetGovRole(address target, bytes4[] memory allowed) public {
        vm.startPrank(admin);
        IAccessManager authority = IAccessManager(accessManager);
        authority.setTargetFunctionRole(target, allowed, C.GOV_ROLE);
        authority.grantRole(C.GOV_ROLE, governor, 0);
        vm.stopPrank();
    }
}
