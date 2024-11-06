// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { DeployAccessManager } from "script/deployment/01_Deploy_Access_AccessManager.s.sol";
import { DeployTollgate } from "script/deployment/02_Deploy_Economics_Tollgate.s.sol";
import { DeployToken } from "script/deployment/03_Deploy_Economics_Token.s.sol";
import { DeployTreasury } from "script/deployment/04_Deploy_Economics_Treasury.s.sol";
import { DeployContentReferendum } from "script/deployment/05_Deploy_Content_ContentReferendum.s.sol";
import { DeployContentVault } from "script/deployment/07_Deploy_Content_ContentVault.s.sol";
import { DeployContentOwnership } from "script/deployment/06_Deploy_Content_ContentOwnership.s.sol";
import { DeployDistributorFactory } from "script/deployment/08_Deploy_Syndication_DistributorFactory.s.sol";
import { DeployDistributorReferendum } from "script/deployment/09_Deploy_Syndication_DistributorReferendum.s.sol";
import { DeployPolicyAudit } from "script/deployment/10_Deploy_Policies_PolicyAudit.s.sol";
import { DeployRightsAccessAgrement } from "script/deployment/11_Deploy_RightsManager_AccessAgreement.s.sol";
import { DeployRightsContentCustodian } from "script/deployment/12_Deploy_RightsManager_ContentCustodian.s.sol";
import { DeployRightsPolicyAuthorizer } from "script/deployment/13_Deploy_RightsManager_PolicyAuthorizer.s.sol";
import { DeployRightsPolicyManager } from "script/deployment/14_Deploy_RightsManager_PolicyManager.s.sol";

import { DistributorImpl } from "contracts/syndication/DistributorImpl.sol";
import { DistributorFactory } from "contracts/syndication/DistributorFactory.sol";

contract OrchestrateInitialDeployment is Script {

    function deployAccessManager() public returns (address) {
        // access
        DeployAccessManager accessManagerDeployer = new DeployAccessManager();
        address accessManager = accessManagerDeployer.run();
        return accessManager;
    }

    function deployEconomics(address accessManager) public returns (address, address) {
        // economic
        DeployTollgate tollgateDeployer = new DeployTollgate();
        tollgateDeployer.setAccessManager(accessManager);
        address tollgate = tollgateDeployer.run();

        DeployTreasury treasuryDeployer = new DeployTreasury();
        treasuryDeployer.setAccessManager(accessManager);
        address treasury = treasuryDeployer.run();

        return (treasury, tollgate);
    }

    function deployContentManagement(address accessManager) public {
        // content
        DeployContentReferendum contentReferendumDeployer = new DeployContentReferendum();
        contentReferendumDeployer.setAccessManager(accessManager);
        address contentReferendum = contentReferendumDeployer.run();

        DeployContentOwnership contentOwnershipDeployer = new DeployContentOwnership();
        contentOwnershipDeployer.setAccessManager(accessManager);
        contentOwnershipDeployer.setContentReferendum(contentReferendum);
        address contentOwnership = contentOwnershipDeployer.run();

        DeployContentVault contentVaultDeployer = new DeployContentVault();
        contentVaultDeployer.setAccessManager(accessManager);
        contentVaultDeployer.setContentOwnershipAddress(contentOwnership);
        contentVaultDeployer.run();
    }

    function deploySyndication(address accessManager, address treasury, address tollgate) public {
        // syndication
        DeployDistributorReferendum distReferendumDeployer = new DeployDistributorReferendum();
        distReferendumDeployer.setTreasuryAddress(treasury);
        distReferendumDeployer.setTollgateAddress(tollgate);
        distReferendumDeployer.setAccessManager(accessManager);
        distReferendumDeployer.run();

        DeployDistributorFactory distributorFactoryDeployer = new DeployDistributorFactory();
        distributorFactoryDeployer.run();
    }

    function deployPolicies(address accessManager) public returns (address) {
        // policies
        DeployPolicyAudit policyAuditDeployer = new DeployPolicyAudit();
        policyAuditDeployer.setAccessManager(accessManager);
        address policyAudit = policyAuditDeployer.run();
        return policyAudit;
    }

    function deployRightsManager(
        address accessManager,
        address treasury,
        address tollgate,
        address policyAudit
    ) public {
        // rights manager
        DeployRightsContentCustodian contentCustodianDeployer = new DeployRightsContentCustodian();
        contentCustodianDeployer.setAccessManager(accessManager);
        contentCustodianDeployer.run();

        DeployRightsAccessAgrement accessAgreementDeployer = new DeployRightsAccessAgrement();
        accessAgreementDeployer.setTreasuryAddress(treasury);
        accessAgreementDeployer.setTollgateAddress(tollgate);
        accessAgreementDeployer.setAccessManager(accessManager);
        address rightsAgreement = accessAgreementDeployer.run();

        DeployRightsPolicyAuthorizer policyAuthorizerDeployer = new DeployRightsPolicyAuthorizer();
        policyAuthorizerDeployer.setAccessManager(accessManager);
        policyAuthorizerDeployer.setPolicyAudit(policyAudit);
        address rightsAuthorizer = policyAuthorizerDeployer.run();

        DeployRightsPolicyManager policyManagerDeployer = new DeployRightsPolicyManager();
        policyManagerDeployer.setRightsAgreementAddress(rightsAgreement);
        policyManagerDeployer.setRightsAuthorizerAddress(rightsAuthorizer);
        policyManagerDeployer.setAccessManager(accessManager);
        policyManagerDeployer.run();
    }

    function run() external {
        address accessManager = deployAccessManager(); // 1
        (address treasury, address tollgate) = deployEconomics(accessManager); // 2
        
        deployContentManagement(accessManager); // 3
        deploySyndication(accessManager, treasury, tollgate); // 4

        address policyAudit = deployPolicies(accessManager); // 6
        deployRightsManager(accessManager, treasury, tollgate, policyAudit); // 7
    }
}
