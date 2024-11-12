// here import all the deploys an wrapp them in
// vm.startBroadcast(pk)
// ... each deployment
// vm.stopBroadcast(pk);// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { DeployAccessManager } from "script/deployment/02_Deploy_Access_AccessManager.s.sol";
import { DeployToken } from "script/deployment/03_Deploy_Economics_Token.s.sol";
import { DeployTollgate } from "script/deployment/04_Deploy_Economics_Tollgate.s.sol";
import { DeployTreasury } from "script/deployment/05_Deploy_Economics_Treasury.s.sol";
import { DeployContentReferendum } from "script/deployment/06_Deploy_Content_ContentReferendum.s.sol";
import { DeployContentOwnership } from "script/deployment/07_Deploy_Content_ContentOwnership.s.sol";
import { DeployContentVault } from "script/deployment/08_Deploy_Content_ContentVault.s.sol";
import { DeployDistributorFactory } from "script/deployment/09_Deploy_Syndication_DistributorFactory.s.sol";
import { DeployDistributorReferendum } from "script/deployment/10_Deploy_Syndication_DistributorReferendum.s.sol";
import { DeployPolicyAudit } from "script/deployment/11_Deploy_Policies_PolicyAudit.s.sol";
import { DeployRightsAccessAgrement } from "script/deployment/12_Deploy_RightsManager_AccessAgreement.s.sol";
import { DeployRightsContentCustodian } from "script/deployment/13_Deploy_RightsManager_ContentCustodian.s.sol";
import { DeployRightsPolicyAuthorizer } from "script/deployment/14_Deploy_RightsManager_PolicyAuthorizer.s.sol";
import { DeployRightsPolicyManager } from "script/deployment/15_Deploy_RightsManager_PolicyManager.s.sol";

import { DistributorImpl } from "contracts/syndication/DistributorImpl.sol";
import { DistributorFactory } from "contracts/syndication/DistributorFactory.sol";

contract OrchestrateInitialDeployment is Script {
    function run() external {
        //access
        // (new DeployAccessManager().run());

        // economics
        (new DeployToken().run());
        (new DeployTollgate().run());
        (new DeployTreasury().run());

        // content
        (new DeployContentReferendum().run());
        (new DeployContentOwnership().run());
        (new DeployContentVault().run());

        // syndication
        (new DeployDistributorReferendum().run());
        (new DeployDistributorFactory().run());

        // policies
        (new DeployPolicyAudit().run());

        // rights manager
        (new DeployRightsContentCustodian().run());
        (new DeployRightsAccessAgrement().run());
        (new DeployRightsPolicyAuthorizer().run());
        (new DeployRightsPolicyManager().run());
    }
}
