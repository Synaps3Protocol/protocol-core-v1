// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { DeployCreate3Factory } from "script/deployment/01_Deploy_Base_Create3.s.sol";
import { DeployAccessManager } from "script/deployment/02_Deploy_Access_AccessManager.s.sol";
import { DeployTollgate } from "script/deployment/04_Deploy_Economics_Tollgate.s.sol";
import { DeployToken } from "script/deployment/03_Deploy_Economics_Token.s.sol";
import { DeployLedgerVault } from "script/deployment/06_Deploy_Financial_LedgerVault.s.sol";
import { DeployTreasury } from "script/deployment/05_Deploy_Economics_Treasury.s.sol";
import { DeployAssetReferendum } from "script/deployment/11_Deploy_Assets_AssetReferendum.s.sol";
import { DeployAssetSafe } from "script/deployment/13_Deploy_Assets_AssetSafe.s.sol";
import { DeployAssetOwnership } from "script/deployment/12_Deploy_Assets_AssetOwnership.s.sol";
import { DeployDistributorFactory } from "script/deployment/09_Deploy_Syndication_DistributorFactory.s.sol";
import { DeployDistributorReferendum } from "script/deployment/10_Deploy_Syndication_DistributorReferendum.s.sol";

import { getGovPermissions as TollgateGovPermissions } from "script/permissions/Permissions_Tollgate.sol";
import { getGovPermissions as TreasuryGovPermissions } from "script/permissions/Permissions_Treasury.sol";
import { getGovPermissions as DistributorReferendumGovPermissions } from "script/permissions/Permissions_DistributorReferendum.sol";
import { getGovPermissions as AssetReferendumGovPermissions } from "script/permissions/Permissions_AssetReferendum.sol";
import { getOpsPermissions as LedgerVaultOpsPermissions } from "script/permissions/Permissions_LedgerVault.sol";

import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

import { console } from "forge-std/console.sol";

abstract contract BaseTest is Test {
    address admin;
    address user;
    address governor;
    address accessManager;
    address ledger;

    modifier initialize() {
        // setup the admin to operate in tests..
        user = vm.addr(2);
        governor = vm.addr(1);
        admin = vm.addr(vm.envUint("PRIVATE_KEY"));
        deployCreate3Factory();
        deployAccessManager();
        deployLedgerVault();
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

        vm.prank(admin);
        // add to governor the gov role
        IAccessManager authority = IAccessManager(accessManager);
        authority.grantRole(C.GOV_ROLE, governor, 0);
    }

    // 02_DeployTollgate
    function deployTollgate() public returns (address) {
        // set default admin as deployer..
        DeployTollgate tollgateDeployer = new DeployTollgate();
        bytes4[] memory tollgateAllowed = TollgateGovPermissions();
        address tollgate = tollgateDeployer.run();
        // add permission to gov role to set fees
        _setGovPermissions(tollgate, tollgateAllowed);
        return tollgate;
    }

    // 02_DeployTollgate
    function deployLedgerVault() public returns (address) {
        // set default admin as deployer..
        DeployLedgerVault ledgerDeployer = new DeployLedgerVault();
        bytes4[] memory ledgerAllowed = LedgerVaultOpsPermissions();
        ledger = ledgerDeployer.run();

        vm.prank(admin);
        // op role needed to call functions in ledger contract
        IAccessManager authority = IAccessManager(accessManager);
        authority.setTargetFunctionRole(ledger, ledgerAllowed, C.OPS_ROLE);
        return ledger;
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
        bytes4[] memory treasuryAllowed = TreasuryGovPermissions();
        address treasury = treasuryDeployer.run();
        _setGovPermissions(treasury, treasuryAllowed);
        return treasury;
    }

    // 05_DeployAssetReferendum
    function deployAssetReferendum() public returns (address) {
        // set default admin as deployer..
        DeployAssetReferendum assetReferendumDeployer = new DeployAssetReferendum();
        bytes4[] memory referendumAllowed = AssetReferendumGovPermissions();
        address assetReferendum = assetReferendumDeployer.run();
        _setGovPermissions(assetReferendum, referendumAllowed);
        return assetReferendum;
    }

    function deployAssetOwnership() public returns (address) {
        // set default admin as deployer..
        DeployAssetOwnership assetOwnershipDeployer = new DeployAssetOwnership();
        address assetReferendum = assetOwnershipDeployer.run();
        return assetReferendum;
    }

    function deployAssetSafe() public returns (address) {
        // set default admin as deployer..
        DeployAssetSafe assetVaultDeployer = new DeployAssetSafe();
        bytes4[] memory referendumAllowed = AssetReferendumGovPermissions();
        address assetReferendum = assetVaultDeployer.run();
        _setGovPermissions(assetReferendum, referendumAllowed);
        return assetReferendum;
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
        bytes4[] memory distributorReferendumAllowed = DistributorReferendumGovPermissions();
        address distributorReferendum = distReferendumDeployer.run();
        // OP role granted to distributor referendum to operate on ledger
        _assignOpRole(distributorReferendum);
        // GOV permission set to distributor referendum functions
        _setGovPermissions(distributorReferendum, distributorReferendumAllowed);
        return distributorReferendum;
    }

    function _setGovPermissions(address target, bytes4[] memory allowed) public {
        vm.startPrank(admin);
        IAccessManager authority = IAccessManager(accessManager);
        // assign permissions to GOV_ROLE for allowed functions to call in target
        authority.setTargetFunctionRole(target, allowed, C.GOV_ROLE);
        vm.stopPrank();
    }

    function _assignOpRole(address target) public {
        vm.startPrank(admin);
        IAccessManager authority = IAccessManager(accessManager);
        authority.grantRole(C.OPS_ROLE, target, 0);
        vm.stopPrank();
    }
}
