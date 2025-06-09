// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { DeployCreate3Factory } from "script/deployment/01_Deploy_Base_Create3.s.sol";
import { DeployAccessManager } from "script/deployment/02_Deploy_Access_AccessManager.s.sol";
import { DeployTollgate } from "script/deployment/04_Deploy_Economics_Tollgate.s.sol";
import { DeployToken } from "script/deployment/03_Deploy_Economics_Token.s.sol";
import { DeployTreasury } from "script/deployment/05_Deploy_Economics_Treasury.s.sol";
import { DeployLedgerVault } from "script/deployment/06_Deploy_Financial_LedgerVault.s.sol";
import { DeployAssetReferendum } from "script/deployment/11_Deploy_Assets_AssetReferendum.s.sol";
import { DeployAssetSafe } from "script/deployment/13_Deploy_Assets_AssetSafe.s.sol";
import { DeployAssetOwnership } from "script/deployment/12_Deploy_Assets_AssetOwnership.s.sol";
import { DeployCustodianFactory } from "script/deployment/09_Deploy_Custody_CustodianFactory.s.sol";
import { DeployCustodianReferendum } from "script/deployment/10_Deploy_Custody_CustodianReferendum.s.sol";
import { DeployAgreementManager } from "script/deployment/07_Deploy_Financial_AgreementManager.s.sol";
import { DeployAgreementSettler } from "script/deployment/08_Deploy_Financial_AgreementSettler.s.sol";
import { DeployRightsAssetCustodian } from "script/deployment/15_Deploy_RightsManager_AssetCustodian.s.sol";

import { getGovPermissions as TollgateGovPermissions } from "script/permissions/Permissions_Tollgate.sol";
import { getGovPermissions as TreasuryGovPermissions } from "script/permissions/Permissions_Treasury.sol";
import { getGovPermissions as CustodianReferendumGovPermissions } from "script/permissions/Permissions_CustodianReferendum.sol";
import { getGovPermissions as AssetReferendumGovPermissions } from "script/permissions/Permissions_AssetReferendum.sol";
import { getOpsPermissions as LedgerVaultOpsPermissions } from "script/permissions/Permissions_LedgerVault.sol";

import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { C } from "contracts/core/primitives/Constants.sol";

import { console } from "forge-std/console.sol";

// dependencies are declared explicitly in each deployment even if nested or repeated to ensure deployment clarity.
// singleton pattern is used underneath to avoid multiple deployments and enforce global consistency.
// each call ensures the dependency is initialized only once and shared across consumers.
abstract contract BaseTest is Test {
    address admin;
    address user;
    address governor;
    address accessManager;

    address agreementManager;
    address agreementSettler;

    address assetSafe;
    address assetReferendum;
    address assetOwnership;

    address custodianReferendum;
    address custodianFactory;

    address rightAssetCustodian;

    address tollgate;
    address treasury;
    address ledger;
    address token;

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
        console.logString(factoryAddress);
        vm.setEnv("CREATE3_FACTORY", factoryAddress);
    }

    // 03_DeployToken
    function deployToken() public {
        // set default admin as deployer..
        DeployToken mmcDeployer = new DeployToken();
        token = token == address(0) ? mmcDeployer.run() : token;
    }

    // 01_DeployAccessManager
    function deployAccessManager() public {
        // set default admin as deployer..
        DeployAccessManager accessManagerDeployer = new DeployAccessManager();
        accessManager = accessManager == address(0) ? accessManagerDeployer.run() : accessManager;

        vm.prank(admin);
        // add to governor the gov role
        IAccessManager authority = IAccessManager(accessManager);
        authority.grantRole(C.GOV_ROLE, governor, 0);
    }

    // 02_DeployTollgate
    function deployTollgate() public {
        // set default admin as deployer..
        deployToken();

        DeployTollgate tollgateDeployer = new DeployTollgate();
        bytes4[] memory tollgateAllowed = TollgateGovPermissions();
        tollgate = tollgate == address(0) ? tollgateDeployer.run() : tollgate;
        // add permission to gov role to set fees
        _setGovPermissions(tollgate, tollgateAllowed);
    }

    // 02_DeployTollgate
    function deployLedgerVault() public returns (address) {
        // set default admin as deployer..
        DeployLedgerVault ledgerDeployer = new DeployLedgerVault();
        bytes4[] memory ledgerAllowed = LedgerVaultOpsPermissions();
        ledger = ledger == address(0) ? ledgerDeployer.run() : ledger;

        vm.prank(admin);
        // op role needed to call functions in ledger contract
        IAccessManager authority = IAccessManager(accessManager);
        authority.setTargetFunctionRole(ledger, ledgerAllowed, C.OPS_ROLE);
        return ledger;
    }

    // 04_DeployTreasury
    function deployTreasury() public {
        // set default admin as deployer..
        DeployTreasury treasuryDeployer = new DeployTreasury();
        bytes4[] memory treasuryAllowed = TreasuryGovPermissions();
        treasury = treasury == address(0) ? treasuryDeployer.run() : treasury;
        _setGovPermissions(treasury, treasuryAllowed);
    }

    function deployAgreementManager() public {
        deployTollgate();
        deployLedgerVault();

        DeployAgreementManager agreementManagerDeployer = new DeployAgreementManager();
        agreementManager = agreementManager == address(0) ? agreementManagerDeployer.run() : agreementManager;
        // OP role granted to custodian referendum to operate on ledger
        _assignOpRole(agreementManager);
    }

    function deployAgreementSettler() public {
        deployTreasury();
        deployLedgerVault();
        deployAgreementManager();

        DeployAgreementSettler agreementSettlerDeployer = new DeployAgreementSettler();
        agreementSettler = agreementSettler == address(0) ? agreementSettlerDeployer.run() : agreementSettler;
        // OP role granted to custodian referendum to operate on ledger
        _assignOpRole(agreementSettler);
    }

    // 05_DeployAssetReferendum
    function deployAssetReferendum() public {
        // set default admin as deployer..
        DeployAssetReferendum assetReferendumDeployer = new DeployAssetReferendum();
        bytes4[] memory referendumAllowed = AssetReferendumGovPermissions();
        assetReferendum = assetReferendum == address(0) ? assetReferendumDeployer.run() : assetReferendum;
        _setGovPermissions(assetReferendum, referendumAllowed);
    }

    function deployAssetOwnership() public {
        deployAssetReferendum();
        // set default admin as deployer..
        DeployAssetOwnership assetOwnershipDeployer = new DeployAssetOwnership();
        assetOwnership = assetOwnership == address(0) ? assetOwnershipDeployer.run() : assetOwnership;
    }

    function deployAssetSafe() public {
        deployAssetOwnership();

        DeployAssetSafe assetVaultDeployer = new DeployAssetSafe();
        bytes4[] memory referendumAllowed = AssetReferendumGovPermissions();
        assetSafe = assetSafe == address(0) ? assetVaultDeployer.run() : assetSafe;
        _setGovPermissions(assetSafe, referendumAllowed);
    }

    // 08_DeployCustodian
    function deployCustodianFactory() public {
        DeployCustodianFactory distDeployer = new DeployCustodianFactory();
        custodianFactory = custodianFactory == address(0) ? distDeployer.run() : custodianFactory;
    }

    function deployCustodianReferendum() public {
        deployCustodianFactory();
        deployAgreementSettler();

        // set default admin as deployer..
        DeployCustodianReferendum distReferendumDeployer = new DeployCustodianReferendum();
        bytes4[] memory custodianReferendumAllowed = CustodianReferendumGovPermissions();
        custodianReferendum = custodianReferendum == address(0) ? distReferendumDeployer.run() : custodianReferendum;
        // GOV permission set to custodian referendum functions
        _setGovPermissions(custodianReferendum, custodianReferendumAllowed);
    }


    function deployRightsAssetCustodian() public {
        deployCustodianReferendum();
        // set default admin as deployer..
        DeployRightsAssetCustodian rightAssetCustodianDeployer = new DeployRightsAssetCustodian();
        rightAssetCustodian = rightAssetCustodian == address(0) ? rightAssetCustodianDeployer.run() : rightAssetCustodian;
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
